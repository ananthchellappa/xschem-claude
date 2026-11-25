# 1765 — Replace takes out ASE-L's own plots only; what was plotted by hand stays

**STAMP:** `v1 claim=fixed tree=ce9da37b3 stamped=2026-11-25 fix=taken open=4 by=driver-1765`

Asked for by the user on 2026-11-25 and built the same day. A review of three readers, each
finding checked by a fourth with its own measurement, found nine defects in the first cut;
all nine are repaired and have rows ("Found by the review"). Four things are open, listed
under "Open".

## What the user wrote

> First, When the plot mode (lower right corner drop-down of ASE-L) says Replace, and
> simulation finishes or user presses the ~ Plot button, plotting should only replace the
> plots that are specified to be plotted in the Saves pane of ASE-L. That is, we don't blank
> the canvas in Waveform Viewer and only draw these waveforms. Those plots that the user
> plotted manually after the sim should be retained. Should they continue to show the
> waveforms from old sim (as opposed to the just complete or latest available sim? yes AND
> no - yes for the "auto plot" that happens because sim finished (BTW, we need to insert an
> option item somewhere in the menu like Cadence ADE-L has - saying WHETHER ASE-L should
> automatically plot after simulation completes. Default can be yes.) -- and, no for the
> case of the user intentionally plotting using the ~ button. In that case, of course, we
> plot what has been selected to plot in ASE-L Saves menu, and Outputs menu (which can
> contain waveforms - say combinations or calculator functions outputs that generate
> waveforms), but we also update the existing user-manually-plotted waveforms.

## What it did before

Under Replace, `~` and the plot a finished run makes emptied the viewer's target subwindow
(`wviewer::clear_subwin`, ruled 2026-10-15 as "Cadence's Replace"): every strip in it went,
the ones the user had made with Direct Plot, the Signal Browser, the Calculator or Add Trace
included. Then every trace in the window followed the new run, because a load of results
drops every other database.

## What was built

### 1. Replace takes out ASE-L's own traces, and nothing else

- **The mark.** A trace ASE-L's plot adds carries `byase 1` in the viewer's model
  (`wviewer::owner_arm`, taken by `wviewer::add_trace`). No other door writes the key, so a
  trace plotted by hand is byte for byte what it was.
- **The removal.** `wviewer::owned_clear` (one undo step) takes the marked traces out of the
  target subwindow, wherever they stand, and leaves every other trace, strip and view.
  `wviewer::auto_plot_strips` then readies ASE-L's strips as before. A surplus one is
  removed only when it is empty; one that still holds a trace plotted by hand stays as an
  ordinary strip.
- **Strips from before the mark.** An `auto 1` strip without `own 1` (a saved state, a
  window an older build plotted into) is treated as it always was: everything in it is the
  tool's (`wviewer::owned_indices`). The strips this change readies carry `own 1`.
- **A pasted copy** of one of ASE-L's traces is the user's own (`paste_traces_in_graphs`).

### 2. Which run a plot made by hand shows

`ase::ui::auto_plot` takes a second argument, `run` or `user` (the default).

- **A finished run (`run`), under Replace:** ASE-L's rows are drawn from the new run. Every
  trace plotted by hand goes on showing the run it was plotted from
  (`wviewer::hold_manual`). Its legend name ends in `@HH:MM:SS`, the time that run's data
  was written.
- **`~` (`user`), under every destination:** every trace is brought to the result in view;
  the ones kept on an earlier run are put back first (`wviewer::hold_release`). With nothing
  ticked the result is read all the same.
- **The other three destinations after a run** behave as before: every trace follows the
  new run.
- **What a finished run does not keep** (`wviewer::hold_manual`'s header has each reason):
  - a run of **another analysis** than the viewer shows (a transient beside an AC run
    would share one X window): nothing is kept, and what was kept before follows the load;
  - a trace that **has nothing to show** on the earlier run (an expression that could not
    be evaluated, a net that result lacked): it follows the load, so the run that brings
    its data draws it;
  - data that holds **no point** (a file read while its run was writing it), and data that
    is **the same** as the window already shows.
- **A load that reads nothing changes nothing** (`wviewer::hold_settle`): after a finished
  run whose file cannot be read, the viewer's data has its own name back and nothing is
  kept; after `~`, the traces stay on the run they were kept on.

How a run is kept: a load of results reads the file anew and drops every other database
(`ase::attach_dbs`). Before the load, the database a hand-made trace draws from is given
another name in the registry (`xschem raw rekey`, new in `src/scheduler.c`), so the data
stays in memory, the load reads the file as a new database beside it, and the trace is
pinned to the kept one by the keys a trace of another database always carried (`rawfile`,
`sim_type`). The kept database is dropped by the first load after no trace names it. A name is never
looked for in it (`wviewer::resolve_signal_db`), so an ASE-L row whose net the new run
lacks is refused as it is with nothing kept.
Nothing of it is saved: a state file holds such a trace as the plain trace it was
(`wviewer::held_plain`), and a model that comes back out of the undo history with a pin to
data that is gone is made plain too (`wviewer::state_apply`).

### 3. Results > Auto Plot Outputs After Simulation

A tick entry below Direct Plot, ADE-L's own words. On (the default), a finished run plots as
above. Off, a finished run changes nothing in the viewer: no trace is added, removed or
redrawn. The session's choice is the state key `plot_after_sim`, written only when it is
not the default; the default is the rc variable `ase_plot_after_sim` (yes when unset). A
user change prints one Command-window line naming the rc line.

## Found by the review, and repaired

Three readers went over the first cut (the viewer's model over time; ASE-L's plot flow and
expressions; the registry, the reload and the key), and each of the six findings they
ranked highest was measured again by another reader on a hidden display. All six stood.
Nine defects in all, each with its row now:

| what a user would have seen | cause | row |
|---|---|---|
| After `~` or Ctrl-R, a hand strip zoomed in X showed the new run in the earlier run's Y window: the trace was off screen | the load counted as the same data, because the finished run's plot had attached that file already | RK13, RL12 |
| With a hand plot on screen, an ASE-L row whose net the new run lacks was drawn from the kept earlier run, with no sentence | the name search reached the kept database | RK14 |
| After a run of another analysis, seconds and hertz shared one X window; one of the two was a sliver | the earlier analysis was kept beside the new one | RK15 |
| An expression that could not be evaluated stayed empty through the run that brought its net back | it was pinned to data that held nothing for it | RK14 |
| A plain hand trace went blank after a run when another hand trace named the result's own database | the database was renamed twice | RK16 |
| After a finished run whose file could not be read, the saved state named `<file>@held1` as its result | the data was renamed before the load was known to read | RK17 |
| A copy of a kept trace, pasted after `~` or into another window, drew nothing | the copy carried the pin | RP7 |
| A file read while its run was writing it (no points) was kept as "the earlier run" | no test for data | RK18 |
| The legend's time was the time of the new run when the session had been opened from a state | the time was taken at the keep | RK19 |

Seen by the readers and left as it is:

- One of ASE-L's traces that the user splits off into a strip of its own goes back to
  ASE-L's strip at the next Replace, and the split-off strip stays, empty.
- Undo back past a finished run's plot brings a hand trace back plain (on the result, with
  no time in its legend); redo keeps it on the earlier run again.

## What was measured on the way

- **A target on a strip that goes left its subwindow.** With the subwindow no longer emptied
  first, a surplus auto strip that held the target strip was removed and the target was
  carried to the next strip, which is another subwindow's when the removed one was the
  last. The next plot followed it there. The target now stays on the first auto strip kept.
  Row PO14 "switched back to single-plot" of `test_ase_plot_outputs` found it.
- **A subwindow nobody touched lost its zoom.** The rebuild after the removal was done once
  the strips had been readied, when their count had changed, and a strip of another
  subwindow holding the same traces took the emptied strip's view (the defect the issue
  1733 review found in the same place). `wviewer::owned_clear` rebuilds while the strips
  are still one for one. Rows PV5 and PV6 found it.
- **A new row drawn in another row's Y window.** A strip that is reused in place kept its
  stored Y. A strip the removal leaves empty now keeps its X and nothing of its Y, the rule
  of the strip a clear leaves (issue 1736). Rows PV7 and PV8 found it.

## Rows

`tests/headless/test_ase_replace_keeps_1765.tcl`, registered in `hcases` and `dcases`.
A "run" is the results file written again with another amplitude and a later time, so the
first point of one vector says which run a trace shows.

| row | what it holds |
|---|---|
| RP1 | which traces are ASE-L's: the marked ones, and every trace of an auto strip from before the marks |
| RP2 | the kept names: made, parsed, pinned (`held_pin`) and taken off byte for byte (`held_plain`); a kept database is named by its file |
| RP3 | the strips ASE-L's plot readies, on the model alone: a hand trace in an auto strip stays; a surplus strip holding one stays as an ordinary strip, an empty one goes; a strip from before the marks is emptied; one of ASE-L's traces in a hand strip leaves; another subwindow is untouched; the target stays in its subwindow; a strip left empty drops its stored Y |
| RP4 | the option: default, rc variable, bad value said once, the state key written only off the default, one log line per change |
| RP5 | a finished run asks for the plot as `run` and only when the option is on; `~` asks as `user` |
| RP6 | `xschem raw rekey`: the name, the data kept, the file read again as a second slot, a taken name refused |
| RP7 | a pasted copy of one of ASE-L's traces carries no mark |
| RP8 | a layout is written with a kept trace as the plain trace it was |
| RK1 | `~` plots the row; its trace is marked, its strip too |
| RK2 | `~` again: the hand strip and the hand trace inside ASE-L's strip stay, the row is there once; one undo step |
| RK3 | a finished run: the row shows the new run, the hand traces the old one (the database, the engine's own fit, the rect); the legend says so; the zoom is kept; the saved state names no kept database |
| RK4 | a second finished run: a trace kept at run 1 stays on run 1, one plotted since stays on run 2 |
| RK5 | `~`: every trace shows the result, the kept data is gone from memory |
| RK6 | a hand expression is kept with its run and evaluated again by `~` |
| RK7 | undo back to a model that held a kept trace, after `~`: it comes back plain |
| RK8 | the option off: a finished run changes nothing in the viewer; `~` then brings everything up |
| RK9 | the menu entry: its place, a real click, the tick following a script, the state file |
| RK10 | Append, New SubWin and New Win after a run keep nothing |
| RK11 | nothing ticked: a run reads nothing; `~` takes out ASE-L's traces, keeps the hand strip and brings it to the result |
| RK12 | multi-plot: the hand strip keeps its place among ASE-L's strips |
| RK13 | a kept strip zoomed in X, then `~`: the X window stays, Y is fitted to the result |
| RK14 | a row whose net the new run lacks is refused, never drawn from the kept run; an expression with nothing to show is not kept, and the run that brings its net draws it |
| RK15 | a run of another analysis keeps nothing, and what was kept follows it |
| RK16 | a hand trace that names the result's own database, beside a plain one: both kept, one kept database |
| RK17 | a finished run whose file cannot be read: the viewer is as it was; the saved state names no kept database |
| RK18 | a results file read while it held no point is not kept |
| RK19 | the legend's time is the time the kept data was written; `@earlier` when the window does not know |

Rows of other suites that stated the rule this replaces were rewritten:

- `test_ase_plot_outputs`: PO16d (the hand strip is gone), PO16e, PO16g, PO16i, PO16k's
  control and PV6 (no read with nothing ticked). Its stand-ins for `ase::ui::auto_plot`
  and `wviewer::add_trace` take the new argument and the mark.
- `test_ase_plot_difference_1727`: GZ6, GZ7 and GG1 say what a difference does now (it
  stays); GG18 to GG20 are new (a difference through a finished run, then `~`). The rows
  about a difference that leaves the strips and comes back by undo (GG1b, GG3, GG5, GG7,
  GG10, GG14 to GG17) clear the subwindow with Graph > Clear SubWin before the press, which
  is what Replace used to do in one.
- `test_ase_persist` G7: one of ASE-L's traces is saved with its mark.
- `test_ase_plot` P5 and P6 (found by the full regression): the Direct-Plot graph stays
  through `~` and through a real run, where the rows said it went.
- `test_wave_grid`: `owned_clear` joins the rebuilds that fold first (GX1, GX4); GX9 reads
  `owned_clear` where it read `clear_subwin`, and has a row for the read `~` makes with
  nothing ticked.
- `test_ase_saved_results_1705` SVR-D1 classifies `ase::ui::reload_source` (issue 1766) as
  a reader that follows the result in view.

The bank questions are `ase-replace-keeps-hand-plots` and `ase-auto-plot-after-sim`;
`ase-dest` was corrected.

## Breaks

Each is one change, run in a copy of the tree against this suite on the display arm and
with `--nogui` (2026-11-25). Rows are this suite's unless another suite is named.

| | what was broken | rows that turn red |
|---|---|---|
| b1 | Replace empties the subwindow again | RK2, RK3, RK4, RK5, RK6, RK7, RK8, RK12 |
| b2 | ASE-L's traces are not marked | RK1, RK2, RK3, RK5, RK6, RK7, RK11, RK12 |
| b3 | an auto strip from before the marks keeps its traces | RP1, RP3 |
| b4 | a finished run keeps nothing | RK3, RK4, RK6, RK7, RK12 |
| b5 | `~` does not put kept traces back | RK5, RK6, RK7, RK12 |
| b6 | a load drops the kept data | RK3, RK4, RK6, RK7, RK12 |
| b7 | the state is saved with the kept names | RK3 |
| b8 | undo brings back a pin to data that is gone | RK7 |
| b9 | a finished run plots whatever the option says | RP5, RK8 |
| b10 | a finished run plots as the user | RP5, RK3, RK4, RK6, RK7, RK11, RK12 |
| b11 | a surplus auto strip is removed with its hand trace | RP3 |
| b12 | a target on a removed strip is carried to the next strip | RP3 |
| b13 | a strip left empty keeps its stored Y | RP3 |
| b14 | a kept trace's legend says nothing | RK3 |
| b15 | a pasted copy keeps the mark | RP7 |
| b20 | the option is written at its default | RP4, RK9 |
| b21 | `~` with nothing ticked reads nothing | RK11 |
| b22 | data that is the same is kept all the same | RK2 |
| b23 | the removal does not rebuild while the strips are one for one | PV5, PV6 of `test_ase_plot_outputs` |
| b25 | the tick does not follow the session | RK9 |
| c1 | after a release the load counts as the same data | RK13 |
| c2 | a name is looked for in a kept run too | RK14 |
| c3 | a run of another analysis is kept | RK15 |
| c4 | a trace with nothing to show is pinned | RP2, RK14 |
| c5 | a trace that names the current database gets a second name (two forms) | RK16 |
| c6 | a load that read nothing leaves the kept names | RK17 |
| c8 | a database with no point is kept | RK18 |
| c9 | the time of a kept run is the time of the keep | RK19 |
| c10 | a pasted copy keeps its pin | RP7 |
| c14 | the result a saved state names is a kept name | RK17 |
| c15 | the run-end plot does not settle after its load | RK17 |

b22 and b25 turned no row red at first; rows were added (RK2's same-data row, RK9's
status-refresh row) and the breaks run again.

## The builder's choices (not ruled by the user)

1. **What counts as plotted by hand: everything ASE-L's own plot did not add.** Direct
   Plot, the Signal Browser, the Calculator, Add Trace, a pasted copy. One of ASE-L's traces
   that the user drags to another strip is still ASE-L's and is replaced from there.
2. **Only Replace keeps hand-made plots on the old run after a run.** Under Append, New
   SubWin and New Win a finished run still moves every trace to the new run, as before. The
   request named Replace.
3. **A kept trace says so in its legend** (`v(out)@14:02:11`). Not asked for; without it a
   trace that did not follow the run looks like one that did.
4. **A kept trace stays kept until `~` or the viewer's reload (issue 1766).** A second run
   of the same analysis, a Direct Plot and a change of destination do not move it. A run
   of another analysis does: nothing is kept across it.
5. **`~` with nothing ticked reads the result** so the hand-made plots follow it. Before,
   that press read nothing.
6. **The option is per session, saved with the state, with an rc default**, like the plot
   destination. It sits in Results, below Direct Plot.
7. **With the option off the viewer is not touched at all at the end of a run**, so it goes
   on showing the earlier run until `~`, the reload or a Direct Plot.
8. **The earlier run is kept in memory, whole**, for as long as a trace shows it. A large
   result is held twice for that time.
9. **The viewer's own Replace still empties the target subwindow** (the Signal Browser's,
   the Calculator's, Add Trace's destination). There the user picks Replace for a plot of
   their own; the request was about ASE-L's drop-down.

## Open

1. The user's ruling on the nine choices above.
2. The user's own look: a re-run with hand-made plots on screen, the legend's time, the
   menu entry.
3. A hand-made difference of two nets (issue 1727) now stays through a run's Replace, where
   R-PD6 said it is removed; the rows and the sentence that said so were rewritten.
4. A copy of a kept trace is pasted as a plain trace (it shows the result). The other
   reading, a copy that stays on the earlier run while that run's data is loaded, was not
   built.

## Not checked

- The user's own screen. Every run here was on a hidden display under openbox.
- A real simulator run: the rows write the results file themselves and call the run-end
  entry (`ase::ui::auto_plot_idle`).
- A digital (VCD) database kept for a hand-made digital trace. The path is the same one
  (`held_pin`'s explicit names, row RP2), but no row loads a VCD.
- Memory with a large result held twice.
