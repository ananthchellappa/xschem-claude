# 1736 — After the viewer's own zoom, a Replace in multi-plot draws the first row in another strip's stored window, and the next strip plotted joins it

**STAMP:** `v1 claim=fixed tree=6e16cf473 stamped=2026-11-24 fix=taken open=1 by=crew-xaxis`

Found by the user on the first use of Plot Difference (issue 1727), 2026-11-23, on the
bundled bench `sky130_tests_ase/tb_bandgap`. Reproduced, its cause shown and repaired on
2026-11-24, on a private Xvfb with openbox, on top of the repairs of issues 1734 and 1727.
One thing is open: the doors that make it write no line in the action log, so the log of
that session cannot say the session went this way. The recipe below gives the first
screenshot exactly; the second one takes one more unlogged door, View > Fit. The last
section has the question that settles it.

## What the user saw

> You will notice that the x-axis extent for this new strip waveform name expr1 is wrong -
> it's from something negative to more than 400 us while the rest of the strips are using
> 0 to 200 us. I have not been able to reproduce this. So, if you find the issue on the
> code, well and good. If not, you can record the issue and wait till I come up with a
> reproducible test-case.

The screenshot, in words. Four strips, top to bottom: the difference, `Icc`, `ENN`, `VBG`.
The difference's strip and `VBG`'s are both on an X axis from about -40u to about 450u.
`Icc` and `ENN` are on 0 to 200u. `VBG`'s Y axis runs from 0 to about 140u, which is the
scale of `Icc`'s strip; `VBG` itself is about 1.2 V, so its strip shows one rising edge
and nothing else. The three Outputs rows are drawn in one colour and the difference in the
next.

So two strips were wrong, not one, and the strip nobody had just plotted, `VBG`, was wrong
in Y as well.

## Reproduced

The bench's session in multi-plot, its three Outputs rows `VBG`, `ENN`, `Icc` plotted by
`~`, on the results file of the user's own session (a real ngspice wrote it).

1. Four presses of Ctrl-z on the viewer canvas, the pointer over the top strip. Every strip
   reads X -34.3u to 453.9u.
2. `~` (the session's plot destination is Replace). `Icc` and `ENN` read 0 to 200u. `VBG`
   reads X -34.3u to 453.9u and Y -6.6n to 140u, `Icc`'s fitted range.
3. A difference of two nets. Its new strip reads X -34.3u to 453.9u.

That is the screenshot: the same two strips wide, the same two on the sweep, `VBG` at
`Icc`'s scale, the same colours. With the repair, step 2 leaves all three strips on
-34.3u to 453.9u, `VBG` on its own Y (up to 1.4), and the difference's strip joins that
one window.

The screenshot carries the door's signature. Between 0 and 200u it has 0.41 of the plot
box's width, and four steps of the viewer's zoom-out leave the sweep 0.8^4 = 0.41 of the
window.

A run that ends does what `~` does (`ase::ui::auto_plot_idle`), so step 2 is also "the
bench was run again".

**The second screenshot needs one more door.** It shows the viewer after a Direct Plot of
`x1.PLUS`: every strip on 0 to 200u, `VBG` on 0 to 1.3, the difference's strip empty.
That does not follow from step 3 by a Direct Plot alone. Measured by the review of this
repair on 2026-11-24, on the product before the repair, with the same bench, the same
results file and the real keys (the repair crew recorded it and did not run it again):

- A real Direct Plot of `x1.PLUS` straight after step 3 leaves `VBG`, the difference and
  the new strip on -34.3u to 453.9u, and `VBG` on Y -6.6n to 140u. That is not the second
  screenshot.
- With View > Fit (the `f` key on the viewer canvas) between the difference and the
  Direct Plot, every strip reads 0 to 200u, `VBG` reads Y -2e-17 to 1.4, and the
  difference's strip is empty on Y -0.041 to 0.03. That is the second screenshot.

So the two pictures together take three doors that write no line in the action log: the
viewer's own zoom, `~` (or a run's plot), and View > Fit.

**The order of the strips says `~` was pressed.** Both screenshots show `Icc`, `ENN`,
`VBG` from the top. The doors the log does hold for that stretch (the plot of the run,
multi-plot set, the strip split) leave the strips `VBG`, `ENN`, `Icc` from the top, on
the product before the repair and after it (same review). `Icc`, `ENN`, `VBG` is the
order a Replace in multi-plot makes: the last row on top.

## The cause

Two things, the first the defect.

**The strip a Replace leaves in place kept another strip's stored view.** The viewer's
own zoom and pan (`wviewer::wheel_zoom`, `wviewer::pan_x`, `wviewer::apply_range`),
View > Fit (`wviewer::fit`), every marker gesture (`wviewer::marker_changed`) and the
strip and trace moves write each strip's X and Y window into the viewer's model. A Replace
empties the target subwindow to one strip (`wviewer::clear_subwin`), and
`wviewer::sw_clear_graphs` made that strip from the subwindow's first auto strip with its
stored X and Y window kept. The rule was written when a run's plot was one strip. In
multi-plot `wviewer::auto_plot_strips` inserts fresh strips above the one that was left
and puts the FIRST Outputs row in it. The first auto strip is the top one, which held the
LAST row. So `VBG` was drawn in the window stored for `Icc`'s strip, and `Icc` and `ENN`
came back in fresh strips, fitted.

**The next strip joined the one stored window.** A strip that has nothing on screen to
take a view from takes the X window of the nearest strip of its subwindow whose X is
known (`wviewer::view_align`). Only `VBG`'s was stored, so the difference's strip took
it. That rule is right; it was handed strips that did not agree.

A zoom made by the engine on the rect (a right-button box, a drag in an axis margin) was
not affected: that view lives on the rects and `ase::ui::auto_plot` already carried it
back by traces (issue 1733). The viewer's own zoom lives in the model, and nothing
carried that.

## What shared the cause

- View > Fit, then `~` or a run, in multi-plot, with no zoom at all: the first row at the
  last row's Y scale.
- A marker placed, then `~` or a run, in multi-plot. A marker stores a window on every
  strip as View > Fit does (measured), so the same follows; this one was not run before
  the repair.
- The viewer's own zoom was kept across `~` and a run on the bottom strip only, with the
  wrong Y, and lost on the others: against issue 1733's ruling that a re-run under
  Replace keeps the zoom.
- A signal plotted with Replace from a viewer door (the Calculator's plot, the signal
  browser's Plot to, the Add Trace dialog) into a zoomed strip, and a plot after
  Graph > Clear SubWin: the new trace in the Y window of the trace that had left.
- A strip split, or a trace moved to a strip of its own, out of a zoomed strip
  (`wviewer::move_trace_in_graphs`): the strip the trace landed on came up on the whole
  sweep beside the zoomed one, and the next strip plotted joined the zoomed one. This is
  the same picture by another door, and the user's log has a split just before a
  difference.

## The repair

A stored view belongs to the traces it was set for.

- `wviewer::sw_clear_graphs`: the strip a clear leaves keeps the X window and X scale of
  the strip it is made from and nothing of its Y.
- `wviewer::sw_stored` reads the stored views of a subwindow's strips before a Replace
  empties it, and `wviewer::sw_stored_give` hands them back once the traces are in: each
  strip takes the stored view of the old strip that held its traces
  (`wviewer::view_map`, the rule a carried view is matched by), and only while its X is
  the same thing on the data shown now (`wviewer::x_same`), so a transient's window is
  not put on a DC sweep. `ase::ui::auto_plot` does this for `~` and a run;
  `wviewer::sw_stored_settle` does it for `wviewer::plot_signals` and the Add Trace
  dialog, where it keeps what they did before: the same signal plotted again with
  Replace shows what it showed.
- After ASE-L's plot a strip of several that took no stored view carries no stored X: it
  joins its subwindow's window as any new strip does.
- `wviewer::move_trace_in_graphs`: an empty strip a trace lands on takes the X window of
  the strip the trace left when both are in one subwindow on one X scale, and is fitted
  in Y.

`wviewer::view_align` is unchanged.

Specs: `doc/claude/specs/waveform_viewer.md`, "Keeping the view across a rebuild", rule
R6; `doc/claude/specs/waveform_viewer_subwindows.md` section 15;
`doc/claude/specs/waveform_viewer_modes.md` section 13 (the empty destination);
`doc/claude/specs/ase_l.md` R-OUT15 and R-PD12.

## Rows

Each was red on the product before the repair, and each band has its sabotage (the suite
headers name which break reddens which row).

- `tests/headless/test_ase_plot_difference_1727.tcl`, band `GZ`, display arm: the user's
  path through the real doors. A real click on the `~` button, real Ctrl-z presses on the
  viewer canvas, `~` again, the real chord and two clicks, a re-run, View > Fit. On a
  results file the suite writes.
- `tests/headless/test_ase_plot_outputs.tcl`, bands `PV7` and `PV8`, display arm: `~` and
  the run-end plot under Replace with a stored view. `PV7` runs on the committed file a
  real ngspice wrote (`tests/headless/data/calc_fixture.raw`); `PV8` needs a transient
  and a DC sweep of the same vectors and writes its two files.
- `tests/headless/test_wave_subwindows.tcl`, rows `SWD4` (the Y half) and `SWW1` to
  `SWW9` on both arms (the pure rules), `SWW10` to `SWW18` on the display arm (the split
  by the Graph menu's entry, Move to a strip of its own, the viewer's Replace, Clear
  SubWin, the Add Trace dialog), on vectors made in the viewer.
- Rows that fenced the old rule and moved with it: `TP18` and `MM11` of
  `tests/headless/test_wave_trace_menu.tcl`, `SP20` of
  `tests/headless/test_wave_split_strip.tcl`.

Why no row caught it before is in `doc/claude/TEST_LESSONS.md` section 1.

## Open: 1 — did the user's session go this way?

Not shown. The action log of that session has no line for the viewer's zoom keys and
wheel, for View > Fit or for `~`, and those are the doors. What the log does hold:

- Two differences in a row both reported as trace `expr1`. Two in a row with nothing
  between them are computed into `expr1` and `expr2` (measured). With `~` between them
  both are `expr1` (measured): under Replace `~` empties the subwindow, the first
  difference's strip with it, and the name is free again. That is the destination rule
  and no defect of the name; it does say that `~` was pressed there, unlogged.
- Before the last difference: the viewer closed and opened again by a run, multi-plot
  set, a strip split, the grid toggled, a difference, a Direct Plot, a run, a
  difference. Those doors alone, replayed, leave every strip on the sweep. With the
  viewer zoomed before the split they give the same X pattern by the split's door (the
  last bullet of "What shared the cause").

The question for the user, in three parts. Before the first screenshot, were Ctrl-z or
Ctrl+wheel used with the pointer over the viewer? Was `~` pressed, or the bench run,
after that and before the difference? And between the two screenshots, was View > Fit
used (the `f` key with the pointer over the viewer, or the menu entry) before the
Direct Plot? In the viewer Ctrl-z zooms OUT, one step a press; over the schematic the
same key zooms the schematic out.

**The user's answer, 2026-11-24:** *"I did zoom in the viewer before first screenshot,
but I don't remember much."* That is the first part: the viewer's own zoom was used
before the first screenshot, which is the door the repair is about. The second and third
parts (`~` or a run after the zoom, View > Fit between the screenshots) are not
remembered, so the session is still not shown to have gone this way, and the user said
to leave the question open. It need not be put again in these words; what would settle
it is the next occurrence, read as below.

**Taken off the user's list, 2026-11-24.** On the sign-off sheet of that day (private
tree's session, relayed here) the user had the question's entry removed from the owed
ledger and said that this issue stays open. Nothing is owed to the user on it and it is
not to be put to them again; this item stays, because the session is still not shown to
have gone this way.

If a strip comes up on another X window again, what tells which door it was is the
stored window of every strip, taken before anything else is pressed. Either of:

- Session > Save State in ASE-L. The state's `viewer` line holds `x1 x2 y1 y2` for each
  strip; a strip the viewer never stored a window for has them empty.
- In the CIW, with the session's key as the log prints it after `wviewer::set_plot_mode`:

  ```
  lmap G [dict get [wviewer::layout_for <key>] graphs] {list [lmap t [dict get $G traces] {wviewer::trace_label $t}] [wviewer::dget $G x1 -] [wviewer::dget $G x2 -] [wviewer::dget $G y1 -] [wviewer::dget $G y2 -]}
  ```

## Not built

- A line in the action log for `~`, for the viewer's zoom and pan by key and wheel, and
  for View > Fit. A session that uses them cannot be replayed from its log, and both
  screenshots of this report needed all three.
- Graph > Clear SubWin, a viewer door's Replace of other signals, and a single strip
  whose rows are all new keep the stored X window, as before. Only the Y is fitted.
- A lone strip keeps its stored X window across a re-run of another analysis, as before.

## The user's rulings (2026-11-24)

From the same sign-off sheet, relayed by the private tree's session in its own words.
Both choices stay as built:

- **What the repair changed for a user.** After a zoom made in the viewer, `~` and a
  re-run under Replace keep that zoom on every strip, in X and in Y, and the stored Y
  stays until View > Fit. A strip split off, or a trace moved to a strip of its own, out
  of a zoomed strip comes up on that strip's X window. A Replace from the Calculator, the
  signal browser or Add Trace is fitted in Y.
- **The port to the private tree** (`/home/analog/port_pdfix`), in code only that tree
  has: in `wviewer::move_trace_in_graphs` a histogram trace keeps that tree's own rule
  (its strip is fitted in X and Y), and every other trace moved to an empty strip keeps
  the X window of the strip it left.
