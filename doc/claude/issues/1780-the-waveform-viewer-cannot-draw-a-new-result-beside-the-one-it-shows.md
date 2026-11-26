# 1780 — the Waveform Viewer cannot draw a new result beside the one it shows

**STAMP:** `v1 claim=fixed tree=40a61028e stamped=2026-11-26 fix=taken open=2 by=driver-1780`

Asked for by the user on 2026-11-26 and built the same day: Alt-Shift-P in the Waveform
Viewer draws the result in view beside what each waveform shows, and Results > Select in
ASE-L no longer plots. An independent review found 32 defects, 24 of them distinct, a second
pass on the repaired code 18 more, 14 distinct, and a last check on the code that went to
the gate four more; they are listed under "The review" with what was done about each. Two
things are open, listed under "Open".

## What the user wrote

> add support for Alt-Shift-P in Waveform Viewer which will plot the latest waveforms from
> currently loaded (note that when a simulation completes, it becomes the de-factor
> currently loaded sim - but in OVERLAY mode. Meaning - if user did a sim and then loaded a
> saved sim result, that one is the currently-loaded sim, but, after that, pressing
> netlist-and-run to generate a new sim result means that one IS the currently-loaded sim).
> Naturally, this only makes sense for the case that the user had turned OFF auto-plot of
> waveforms upon sim completion. If that is not the case and Waveform Viewer already has
> latest sim results for ALL shown waveforms, then she gets a Pop Up saying latest already
> shown because of (specify where in Menu the option is located) auto-plot. Overlay means
> that, in each strip, the new version of the waveform will be plotted in a slightly
> different color.

## What was asked back, and the answers

Three questions were put before anything was built (2026-11-26).

1. **Pressed again after another run: every version, or the last two?** Answer: every
   version. Each press adds the newest in a further step of the colour; Ctrl-R goes back to
   one.
2. **Only the waveforms in the viewer, or ASE-L's ticked outputs that are not shown too?**
   Answer: the waveforms shown only.
3. **Results > Select redraws every waveform from the selected result at once, so the key
   would find nothing to overlay after a select. Leave it, or keep the plots when Auto Plot
   is off?** Answer, in the user's words: "I didn't know about this. Selecting a simulation
   result using Results > Select should NOT automatically plot waveforms. That should only
   happen after a sim finishes with auto-plot option ticked. Thanks for notifying. Update as
   I say. Selecting should not plot. If user selects a saved result, she must also press
   plot button to have new results plotted. Alt-Shift-P then overlays the saved result on
   it, and Ctrl-R replaces with it - "it" being new just selected result".

## What was built

Spec: `doc/claude/specs/waveform_viewer.md`, "Overlay Latest". FAQ Q112. Guide:
`doc/waveform_viewer_guide.html`, the row of Alt-Shift-P in §9.1.

- **The key.** Alt-Shift-P on the viewer's `WaveViewer` bind tag
  (`wviewer::install_default_binds`), the same chord with Caps Lock on, and **File >
  Overlay Latest** showing it.
- **What it overlays** is what Ctrl-R reads (`wviewer::reload_source`): the result the
  window's ASE-L session has in view. A finished run puts the latest run in view; a saved
  result, or a file picked by path, chosen with Results > Select stays in view until the
  next run.
- **What it does** (`wviewer::overlay_latest`). When the viewer's data is not that result,
  every trace that has data is kept on what it shows and the result is read. Then every
  waveform none of whose versions follows the result gets a new trace in its strip that
  shows it, in the same layer and a shade. One undo step, one sentence, one replayable log
  line.
- **The shade** is part of the trace's colour token on the strip (`4+40`): `draw_graph()`
  reads it and `graph_shade()` paints the trace that far towards white or black. The
  shades of the first, second, ... later version are the rc variable
  `wviewer_overlay_shades` (default `40 -35 65 -60`; commented out in
  `src/cadence_style_rc`).
- **Which version is which.** The earlier versions' legend names end in the time their
  data was written, in the day too when it is not today's, or in the name a saved result
  was saved under; the cursor read-out and the Delete dialog name them the same way.
- **The versions stay on their data** when another door loads (a Direct Plot after
  another run).
- **Back to one version of each**: Ctrl-R, ASE-L's plot button, a saved state, and a model
  that comes back out of the undo history after its kept data is gone. The trace that
  stays is drawn in its layer's own colour.
- **The pop-up** (`wviewer::notice`), a small window that is not modal, when there is
  nothing to overlay: every waveform is on the result (it names Results > Auto Plot
  Outputs After Simulation when a finished run's plot is why), no waveform is plotted, or
  the result's file holds none of the analysis the waveforms show.
- **Results > Select plots nothing** (`ase::ui::rsel_commit`). The waveforms are pinned to
  the data they show before the selected result becomes current, ASE-L's own traces
  included; the dialog's status and the CIW name the gestures that bring the selected
  result in.

## Found on the way

- **`expr` hands `+40` back as 40.** The shade of a later version was written without its
  sign, which `draw_graph()` reads as no shade. Found by the suite's first run; the sign is
  put on outside `expr` (row `OP1`).
- **A parameter named like a local.** `wviewer::hold_manual` has a local `all`; the new
  argument of that name was overwritten by it and every key press ended in a background
  error. The argument is `every` (row `OV2`).
- **The bold trace moved to the wrong trace after Ctrl-R.** Taking a later version out
  renumbers the traces after it in the model, and the fold of the load that follows read
  the strips' old numbers back over it. The strips are folded before a version goes and
  rebuilt at once after (`wviewer::unpin_and_tidy`; row `OV16`, found when the row was
  written).
- **Two quiz proofs named lines that moved** (`ase-replace-keeps-hand-plots`: the legend
  cue's format is in `wviewer::when_text` now; `wave-reload-ctrl-r`: its explanation said
  no trace is removed). Both follow.
- **The number.** The work began as issue 1773, the number both this clone's pointer and
  `~/private/xschem-private`'s read that morning. A worktree of that clone took 1773 an
  hour later, before anything was recorded here; the review found it (P5), and the work
  was renumbered to 1780 before it was committed, leaving 1774 to 1779 to that clone
  (`NUMBERING.md`).

## The review

Three reviewers read the change with one lens each (which data a trace shows; what the
user gets against their words; the painter, the rest of the tree and the rows), ran their
own scenarios in copies of the tree, and a second agent tried to reproduce every finding.
**32 findings, all 32 confirmed, 24 distinct.** 22 were repaired or answered (D4 in part),
each behaviour with a row; U7 is left as it is and said in the guide; P9 is not this change. Ids are the reviewers' (D data, U user, P painter).

| finding | what was wrong | what was done | rows |
|---|---|---|---|
| D1, U2 | going back and forth between a saved result and the last run gave a waveform the same data a second time, in another shade, at every round | a waveform with ANY version that follows the result gets none (only the latest version was asked); a kept version on the very data loaded again loses its pin, whichever version it is; the dialog says the waveforms stayed only when one of them does not show the selected result | `OP3`, `OV18` |
| D2 | a file picked by path in Results > Select could be shown by none of the three gestures the dialog named: before this issue the select itself drew it | the dialog notes the file and the analysis of the row it selected, and Ctrl-R and Alt-Shift-P read that until the next run; the sentence names the plot button only where the plot button reads the selected result | `OV19` |
| U1, D5, P3, U5 | another analysis: a false sentence ("the waveforms are of the ac analysis" over transient ones), an overlay refused though the file held the analysis shown, a saved transient that Ctrl-R read "as its ac analysis" | the analysis the waveforms show decides how the result's file is read; Ctrl-R reads a selected row as its own analysis; the one sentence left is said when the file holds none of the analysis shown | `OV12`, `OV20` |
| D3 | a finished run of another analysis took the pins off and left each waveform as one curve drawn twice, which Ctrl-R and the plot button never removed | the later versions go where the pins come off, and Ctrl-R and the plot button look for them with nothing kept too | `OV16`, `OV21` |
| D4 | a Direct Plot after another run moved the version that followed the result to the new data: the run it was drawn from was gone | a load made by any door keeps the versions on their data first; a waveform with ONE version follows such a load as before (left: "Known, and left") | `OV22` |
| D6 | each Results > Select round trip left one more copy of a result in memory, named by no trace | the kept copies no trace names are unloaded, and the selected database stays current | `OV18` |
| D7 | a pasted copy of a later version kept its family number: where it landed it counted as a version of another waveform, and Ctrl-R deleted it | a pasted copy carries no mark | `OV21` |
| D8, P4, U6 | a later version left alone (its first trace deleted, or moved to another strip) kept its shade for good, into saved states | a trace that is the only version of its waveform in its strip and is not kept is an ordinary trace again | `OP4`, `OV21` |
| D9 | after a read that failed, a kept version's legend said `@earlier`, so two versions had one name; a trace of a file loaded beside the result was given the result's time | a kept trace's time is read from what was noted of its own database at its load | `OV23` |
| D10 | the scripting door `wviewer::display_raw` noted a file's state when the engine had only switched to its copy in memory: the key then said the latest result was shown over older data | it notes only what the engine read | `OV23` |
| D11, P8, U12 | arms of the new code that no row ran; one of them read the result, pinned a trace and logged nothing; an undo point was taken in a tab the press did not change | rows for them; a press that read is logged; the undo point is taken when the tab shown gains a version. Still run by hand only: listed under "Not checked" | `OV23`, `OV25` |
| P1 | a white trace's later version was painted white: a shade towards white of white | a colour with no room that way goes the other way | `OV24` |
| P2 | the cursor read-out bar and the Delete dialog named every version of a waveform alike | both carry the legend's cue | `OV23`; `GG18` of `test_ase_plot_difference_1727` |
| P5 | the issue number was taken by another checkout | renumbered to 1780 ("Found on the way") | |
| P6 | two rows turned on the clock (a suite started just before midnight); two runs of an earlier day within a minute had one legend name | the rows take both forms of the cue; the form for another day carries seconds | `OP5` |
| P7 | a row about "no shade left in the layer" could not fail | the row is gone; the pixel rows that follow it are the fence (breaks `c2`, `c5`) | `OV5`, `OV7` |
| P9 | two reds in neighbouring suites | not this change: `test_wave_sigbrowser_keys` (not registered) is red at the commit before on rows BK22, BK29 and BK31; the red of `test_selection_dim_1769` in one reviewer's batch of 22 suites on one display did not happen again in the second reviewer's | |
| U3 | the pop-up blamed Auto Plot when a reload or the plot button was why the waveforms were current, and called a selected saved result "the latest" | it blames the option only when a finished run's plot put the data there and the option is still ticked; a result chosen in the dialog is "the result in view" | `OV25` |
| U4 | the pop-up took the keyboard, and swallowed the Ctrl-R its own sentence recommends | it asks for no focus; typed on it, Ctrl-R and Alt-Shift-P do what they do in the viewer, any other key closes it | `OV25` |
| U7 | after a select, a finished run under Append leaves the kept traces on the data they show, against the guide's sentence | the guide and the spec say so (left: "Known, and left") | |
| U8 | a select drew a trace that had had no data, under a sentence that said nothing moved | every trace that named no database is pinned, one with nothing to show too | `OV25` |
| U9 | five sentences in the guide, a quiz explanation, two specs and a comment that the code did not make true | corrected | |
| U10 | Reload's sentence counted, as "showing the result again", traces it then took out | it counts the ones that stay | `OV7` |
| U11 | row GH2 of `test_wave_grid` did not see a default bound through a variable | row `GH2b` names the two such places; the Caps Lock form is bound only while the key is the overlay's | `GH2b`, `OV1` |

### The second pass, on the repaired code

One agent ran every finding of the first review again on the repaired tree; another read
what the repairs changed and attacked it; a third and a fourth reproduced what the two
reported. **The first review's 32: gone, or left as documented, except where the table
below says otherwise. 18 new findings, all confirmed, 14 distinct**: nine of them in what
the repairs had added, three that had been there since the first build (R3/X7, R4, X9),
two about records (R6, R8). All 14 were dealt with.

| finding | what was wrong | what was done | rows |
|---|---|---|---|
| R1 | after a saved result of another analysis was selected, the plot button drew ASE-L's row as a sliver on the old axis and left the hand trace behind; the small window promised the plot button and named the saved result by the run's file name | the plot button reads a selected saved result or last run as the analysis of the row the dialog chose; the window names the saved result and promises Ctrl-R alone | `OV27` |
| R2, X4 | after a select round trip `u` brought a trace back on other data: the kept copy its model was pinned to had been unloaded (by the repair of D6), and kept again under a new name | a copy the undo history is pinned to is not unloaded, and a file state that is kept again gets the kept name it had (taken out once as unreachable and put back: finding L3) | `OV18`, `OV26`, `OV29` |
| R3, X7 | after a select, a file typed into the viewer's Location bar moved no waveform | the bar takes the pins off before it loads and puts them back when the engine refuses the file | `OV26` |
| R4 | the dialog's Loaded list had a row for the kept copy, and selecting it said "No such result file '...@held1'" | a kept copy is no row of that list | `OV26` |
| R5, X5 | the three gestures disagreed on the analysis: after the key drew a new AC run beside an AC waveform, Ctrl-R put the transient on that strip; after the plot button, the row the dialog had chosen still ruled Ctrl-R | Ctrl-R reads the analysis the waveforms show unless the dialog chose the row; the plot button reads the row the dialog chose | `OV20`, `OV27` |
| R6 | arms of the new code no row ran | rows for the two sentences about another analysis and for the dialog's note; the rest is listed under "Not checked" | `OP6`, `OV27` |
| R7, X6 | a black trace's first and fourth later versions were one grey: the repair of P1 used one amount for both ends | 20 less far when the shade was towards white, 20 further when it was towards black | `OV24` |
| R8 | the change had no issue file and no entry in the owed ledger | this file; a rule and a look entry | |
| X1 | after a select round trip the Signal Browser plotted a signal from another database than the one its header named: its list was read before the kept copy was named or unloaded | it is read again after | `OV26` |
| X2 | Tab typed on the small window raised a background error: Tk's own Tab binding ran on the window that had just been destroyed | every key binding of the window ends the event there | `OV25` |
| X3 | a later version of ASE-L's row in a tab or subwindow that was not the target moved to the new run at a finished run under Replace, when a trace made by hand stood in the window | that run's keep covers every version of a waveform | `OV28` |
| X8 | the small window blamed Auto Plot after a Direct Plot had moved the waveforms | a Direct Plot and a Plot Difference say that they loaded | `OV28` |
| X9 | a trace kept on the run that was then saved got the saved copy as a second, identical curve | a saved copy of the kept result counts as the same data | `OV17`, `OV28` |
| X10 | four sentences in the guide and three specs | corrected | |

### The last check, on the code that went to the gate

While the full regression ran on the repaired tree, one agent ran the second pass's 18
findings again and attacked what its repairs had added, in a copy of its own. **The 18:
gone. Four new findings**, each run again by the builder with the agent's own script
before and after its repair, and each with a row. The regression was then run a second
time, on the tree as committed.

| finding | what was wrong | what was done | rows |
|---|---|---|---|
| L1 | Ctrl-R no longer brought the waveforms to a run of another analysis (AC waveforms; the session's analyses changed and the new file holds a transient alone): the read was refused and nothing moved, under a small window that says "Ctrl-R replaces the waveforms with that result". The repair of R5/X5 had left no way back to the analysis ASE-L names | when the file holds none of the analysis shown, Ctrl-R reads it as the analysis ASE-L names | `OV29` |
| L2 | a finished run under Replace fitted the X window of ASE-L's strip again when its row had versions, against the ruling of issue 1733. The repair of X3 pins every version before the view is read, so the row that came back shared no trace with the strip that was zoomed; with no trace made by hand in the window the zoom had been lost since the first review's repairs | the view on screen and the stored views are matched with ASE-L's kept traces named as before the pin (`wviewer::recs_owned_plain`); the same holds for a row kept by Results > Select | `OP7`, `OV29` |
| L3 | after a reload between two selects, `u` turned a kept waveform into the saved result, with no cue. The code that gives a file state kept again the kept name it had (`wviewer::held_name_new`, the repair of R2/X4) had been taken out an hour before as unreachable, because break `m2` turned no row red: the sweep spares the copies the undo history names, but a load drops them | the code is back, with the rows that reach it at two of its three callers | `OV29` |
| L4 | the Super key, AltGr, Hyper and Scroll Lock typed alone closed the small window, against "a modifier alone does nothing" | one test for a modifier or a lock key (`wviewer::key_is_modifier`) | `OP7`, `OV29` |

The second run of the neighbouring suites then caught the repair of L2 itself: its line
stood inside a block that row `GX9` of `test_wave_grid` reads as text, and was moved below
it.

## Rows

`tests/headless/test_wave_overlay_latest_1780.tcl`, registered in `hcases` and `dcases`:
62 checks without a display and 276 with one.

| band | what it holds |
|---|---|
| OP1 | the shades: the default list, an rc list, a list that is no list |
| OP2 | a trace's shade rides its colour token on the strip, and only a shade the engine reads |
| OP3 | which waveforms get a later version: one with every version kept; none when a version follows the result; the pin off when the kept data is the data loaded again; another analysis, a net the result lacks, an expression, a file of its own, ASE-L's own trace, the family numbers |
| OP4 | the later versions go when every version shows the same data; a trace left alone is an ordinary trace again; what is saved holds none |
| OP5 | the legend cue: a saved result by its name, another day by its date and time |
| OP6 | what the dialog chose last, while it is the session's selection; which gestures the dialog names |
| OP7 | which keys are a modifier or a lock key; ASE-L's kept traces named as before the pin, for the matching of a view |
| OV1 | the key, its Caps Lock form (which follows the key), the menu entry |
| OV2 | after a run that plotted nothing: a real Alt-Shift-P adds the new run beside the old one in every strip, in a shade; one undo step, one sentence, one log line |
| OV3 | pressed again with nothing new: the small window, nothing changed, nothing logged |
| OV4 | another run and the key again: three versions |
| OV5 | the screen: the layer's own colour and both shades are painted, by pixel count |
| OV6 | `u` and `U` across the last press |
| OV7 | Ctrl-R goes back to one version of each, in its own colour; its sentence; `u` after it |
| OV8 | after a finished run that plotted: only the trace made by hand gets a version; the window names ASE-L's menu entry; one window, Return and Escape |
| OV9 | ASE-L's plot button after an overlay: one version of each |
| OV10 | Results > Select plots nothing and keeps the zoom; the status sentence; Alt-Shift-P overlays the saved result; Ctrl-R replaces with it |
| OV11 | selecting the result the plots show again takes the pins off |
| OV12 | a file that holds none of the analysis shown; no waveform; a live run; a read that fails; the file as it was read; no file; no window |
| OV13 | a zoom is kept; an expression gets its version; a net the result lacks is left and counted |
| OV14 | a second tab gets its versions; a saved state holds one version; Ctrl-R in one tab tidies the other |
| OV15 | the doors that read a file into the viewer by hand: the key knows what they read |
| OV16 | the trace highlight and the bold trace follow their trace when a version before it goes, with something kept and with nothing kept |
| OV17 | another file with the result's time and size is not the result |
| OV18 | back and forth between a saved result and the last run adds nothing twice and leaves no copy in memory |
| OV19 | a file picked by path in the dialog is what the keys read, until the next run |
| OV20 | the analysis the waveforms show decides how the result is read; the row the dialog chose; a saved transient under a session that plots AC |
| OV21 | a later version left alone; a pasted version; a finished run of another analysis |
| OV22 | a load made by another door leaves the versions on their data, also when it reads nothing |
| OV23 | the legend cue after a failed read; the read-out and the Delete dialog; a failed Ctrl-R with versions; a press that only read; the undo point; a file loaded beside the result; the scripting door |
| OV24 | a colour with no room towards white or black |
| OV25 | what the small window blames; its keyboard, Tab included; a trace with no data at a select |
| OV26 | `u` after a select round trip; the dialog's Loaded list; the Signal Browser; the viewer's Location bar after a select |
| OV27 | Ctrl-R, the key and the plot button read one analysis; the row the dialog chose against the analysis shown; a window that shows two; a saved result of another analysis |
| OV28 | a version in a tab that is not shown at a finished run under Replace; who is blamed after a Direct Plot; a saved copy of the kept run |
| OV29 | Ctrl-R when the file holds none of the analysis shown, and who loaded after it; the zoom and the ranges of ASE-L's strips across a finished run under Replace, for rows with versions and a row kept by a select; `u` after a reload between two selects; the kept name of a saved result kept twice; the Super key and AltGr on the small window |

Other suites that moved with it: `test_wave_grid` (`GH0`: 23 keys, 18 accelerators;
`GH2b`; the census of rebuild sites `GX1`/`GX4` holds `overlay_latest` and
`unpin_and_tidy`; the census of data loaders `GZP33` holds `held_sweep`),
`test_wave_sigbrowser` (`BT09`), `test_wave_reload_1766` (`RL1`: Overlay Latest stands
between Reload and the separator), `test_ase_replace_keeps_1765` (`RK19`: a time is
unknown only for data of which nothing was noted), `test_ase_plot_difference_1727`
(`GG18`: the read-out bar names a kept difference with its time), `test_startup_quiz` (the
two proofs above, and the new question `wave-overlay-latest`), and two suites the
regression does not run, `test_wave_sigbrowser_i12` (`BX13`) and
`test_wave_sigbrowser_keys` (`BK10`).

## Breaks

Each is one change to the code, run in a copy of the tree against this suite on both
arms, the binary rebuilt for a change in C (2026-11-26, on the code as committed).
**152 breaks, 152 turn at least one row red.** The table was made four times. Before the
review: 78 breaks, three turned no row red, and `OV15`, `OV16` and `OV17` were tightened
for them. After the first review's repairs: 120; four turned none (`t25`, `t45`, `n5`,
`n17`) and each got a row (in `OV25`, `OV16`, `OV16`, `OV20`). After the second pass's
repairs: 135, and a 136th, `m2`, that turned none; the code it broke was taken out as
unreachable, which was wrong (finding L3). On the code as committed, after the last
check: the 135 (four of them rewritten for the changed text), `m2` again and 16 for the
last repairs, all run again. Two turned none at first: `p4`, which got the two-row case
of `OV29`, and `m6`, which the repair of L1 had masked in the row that used to catch it
(a file that holds one analysis) and which got a row in `OV27` on a file that holds
both. The table below is that last run.

| | what was broken | rows that turn red |
|---|---|---|
| c1 | the painter does not read a shade off a colour token | OV5, OV6 |
| c2 | the shade is not taken out when its node is drawn | OV7 |
| c3 | a shade below zero goes towards white too | OV5, OV24 |
| c4 | taking a shade out leaves it in the colour table | OV5, OV6, OV24 |
| c5 | taking a shade out leaves it in the layer GC | OV7, OV21 |
| c6 | the shade is not put into the layer GC, so the curve keeps the own colour | OV5 |
| c7 | the amount of the shade is ignored | OV5, OV24 |
| c8 | a colour with no room towards white keeps a shade that cannot be seen | OV24 |
| c9 | one amount for both ends: a black trace has one grey for two versions | OV24 |
| t1 | the strip does not carry the shade | OP2, OV5, OV6, OV21 |
| t2 | a shade above zero is written without its sign | OP1, OP3, OV2, OV4, OV5, OV6, OV8, OV10, OV14, OV16, OV18, OV19, OV20, OV21, OV23, OV25, OV28, OV29, OV15 |
| t3 | the reader's fallback is another list than the declared default | OP1 |
| t4 | a zero or a percent past 95 in the rc list is taken | OP1 |
| t5 | any shade word is written to the strip | OP2 |
| t7 | a later version carries no shade | OP3, OV2, OV4, OV5, OV6, OV8, OV10, OV14, OV16, OV18, OV19, OV20, OV21, OV23, OV25, OV28, OV29, OV15 |
| t8 | the first trace takes no family mark | OP3, OV3, OV4, OV6, OV7, OV8, OV9, OV10, OV11, OV14, OV16, OV18, OV19, OV20, OV21, OV22, OV23, OV25, OV27, OV29 |
| t11 | a trace of a net the result lacks gets a version | OP3, OV13, OV23 |
| t12 | the later version is put first in its strip, not last | OP3, OV2, OV4, OV6, OV8, OV10, OV13, OV14, OV16, OV18, OV19, OV20, OV21, OV22, OV23, OV25, OV28, OV29, OV15 |
| t15 | family numbers start again at 1 | OP3 |
| t16 | nothing is kept before the result is read | OV2, OV4, OV5, OV6, OV7, OV13, OV14, OV16, OV20, OV21, OV22, OV23, OV25, OV27, OV28, OV29, OV15 |
| t17 | only the traces made by hand are kept before the result is read | OV2, OV4, OV6, OV7, OV13, OV14, OV16, OV20, OV21, OV23, OV25, OV28, OV29 |
| t19 | the overlay is not logged | OV2, OV8 |
| t20 | an expression's later version is not computed | OV13 |
| t21 | the rebuild after the versions fits every strip again | OV13 |
| t22 | the small window never opens | OV3, OV8, OV11, OV12, OV18, OV23, OV25, OV27, OV28, OV29, OV15 |
| t23 | the small window's sentence does not go to the CIW | OV3 |
| t26 | the key reads while a run is live | OV12 |
| t29 | an empty window is not told from one with waveforms | OV12 |
| t30 | Alt-Shift-P is not bound | OV1, OV2, OV3, OV4, OV5, OV6, OV7, OV8, OV10, OV11, OV12, OV13, OV14, OV16, OV18, OV19, OV20, OV21, OV22, OV23, OV25, OV27, OV28, OV29, OV17, OV15 |
| t31 | the Caps Lock form of the chord is not bound | OV1 |
| t32 | the key travels on to the tags below | OV1 |
| t33 | the File menu has no Overlay Latest | OV1, OV8 |
| t33b | the menu entry shows no key | OV1 |
| t34 | the versions are added to the tab shown only | OV14, OV23 |
| t36 | the latest version stays and the first trace goes | OP4, OV7, OV27 |
| t37 | a version still kept on an earlier result goes too | OP4, OV6, OV7, OV18 |
| t38 | the first trace keeps its family mark when it is alone again | OP4, OV7, OV9, OV14, OV16, OV21 |
| t39 | a saved state keeps the later versions | OP4, OV14 |
| t40 | the snapshot is not written through saved_graphs | OP4, OV14 |
| t41 | the tab records are not written through saved_graphs | OP4, OV14 |
| t42 | a model out of the undo history keeps versions that show the same data | OV7 |
| t43 | the tabs that are not shown keep their later versions | OV14 |
| t44 | the trace highlights do not follow their traces | OV16 |
| t47 | Reload's sentence does not count the versions taken out | OV7, OV27 |
| t48 | a trace kept on a saved result does not say its name | OP5, OV11, OV18 |
| t49 | data of another day says the time of day only | OP5 |
| t50 | a saved name the strip cannot carry is used all the same | OP5 |
| t52 | nothing is read before the select | OV10, OV11, OV18, OV19, OV20, OV25, OV26, OV27, OV28, OV29 |
| t53 | the select's rebuild fits every strip again | OV10 |
| t56 | nothing is noted of the database the select made current | OV11, OV18, OV26, OV17 |
| t59 | the select keeps even when the data in view did not move | OV11 |
| t60 | the kept name does not take the note of its database with it (select) | OV11, OV18, OV20, OV26, OV17 |
| t61 | a load does not note what it read | OV3, OV8, OV12, OV18, OV20, OV23, OV25, OV26, OV28, OV29, OV17 |
| t62 | the kept name does not take the note of its database with it (the key) | OV12, OV28, OV17 |
| t63 | a name given back does not take its note back | OV12 |
| t64 | the file written again is taken for the data shown | OV2, OV4, OV5, OV6, OV7, OV12, OV13, OV14, OV16, OV20, OV21, OV22, OV23, OV25, OV27, OV28, OV29, OV15 |
| t65 | another file with the same time and size is taken for the data shown | OV17 |
| t66 | a restore does not note what it read | OV15 |
| t67 | the Location bar does not note what it read | OV15 |
| t6 | a later version carries no version number | OP3, OV2, OV4, OV5, OV6, OV8, OV10, OV13, OV14, OV16, OV18, OV19, OV21, OV22, OV23, OV25, OV28, OV29, OV15 |
| t9 | a version kept on the very data loaded again is not unpinned: the waveform gets that data twice | OP3, OV20, OV17 |
| t10 | a trace kept on another analysis gets a version | OP3, OV27 |
| t13 | the first version counts as the latest | OP3, OV4, OV5, OV8, OV22, OV23, OV25 |
| t14 | a trace of a file that is not loaded any more gets a version | OP3, OV23 |
| t18 | the versions are no undo step | OV2, OV6 |
| t24 | the window never names ASE-L's option | OV8, OV25 |
| t25 | the window names ASE-L's option whatever it is set to | OV25 |
| t27 | the result is read as the analysis ASE-L names, whatever the waveforms show | OV12, OV20, OV27, OV29 |
| t28 | a read that found nothing is taken for one that read | OV12, OV27, OV29 |
| t35 | Ctrl-R and the plot button leave the later versions in | OV7, OV9, OV10, OV11, OV14, OV16, OV19, OV21, OV27, OV29 |
| t45 | the strips are not folded before the later versions go | OV16 |
| t46 | the strips are not rebuilt when the later versions go | OV16 |
| t51 | the select does not keep the plots (it plots, as before) | OV10, OV11, OV18, OV19, OV20, OV25, OV26, OV27, OV28, OV29 |
| t57 | a trace kept on the data just selected again stays kept | OV11, OV18, OV26, OV17 |
| t54 | the dialog's status does not say the waveforms stayed | OV10, OV18, OV19, OV20, OV25 |
| t55 | the CIW does not say the waveforms stayed | OV10 |
| t58 | the select keeps the traces made by hand only (ASE-L's own follow) | OV10, OV11, OV18, OV19, OV20, OV26, OV27, OV28, OV29 |
| t68 | the scripting door notes the file even when the engine did not read it | OV23 |
| t68b | the scripting door never notes what it read | OV15 |
| t69 | a keep of every trace leaves ASE-L's own out | OV2, OV4, OV6, OV7, OV10, OV11, OV13, OV14, OV16, OV18, OV19, OV20, OV21, OV23, OV25, OV26, OV27, OV28, OV29 |
| t70 | a keep of the versions alone pins every trace | OV22 |
| n1 | only the latest version is asked whether it follows the result | OP3, OV18, OV19, OV20, OV21, OV22, OV23, OV25, OV26, OV27, OV28, OV29, OV17, OV15 |
| n2 | only the latest version is asked whether its data is the data loaded again | OP3 |
| n3 | a later version left alone keeps its marks and its shade | OP4, OV21 |
| n4 | a kept version left alone loses its marks | OP4 |
| n5 | with nothing kept, Ctrl-R and the plot button leave versions that show the same data | OV16 |
| n6 | a finished run of another analysis leaves each waveform drawn twice | OV21 |
| n7 | a load made by another door moves the version that follows the result | OV22 |
| n8 | the keep made at a load is not settled | OV22 |
| n9 | a kept version's time is the window's, not its own data's | OV23 |
| n10 | a select pins only the traces that have data: an empty one is plotted by it | OV25 |
| n12 | the kept copies no trace names are left in memory | OV18, OV26 |
| n13 | unloading a kept copy leaves another database current | OV11, OV18, OV26 |
| n14 | the dialog does not note what it chose | OV18, OV19, OV20, OV27 |
| n15 | the viewer's keys do not read a file picked by path | OP6, OV19 |
| n16 | the viewer's keys read the session's analysis, not the selected row's | OP6, OV20, OV27 |
| n17 | a new run does not forget what the dialog chose | OP6, OV20, OV27 |
| n18 | the dialog names Alt-Shift-P for a result of another analysis than the waveforms | OP6, OV20 |
| n18b | the dialog names the plot button for a file picked by path | OP6, OV19 |
| n19 | the dialog says the waveforms stayed when every one of them shows the selected result | OV11, OV18 |
| n20 | the small window swallows Ctrl-R | OV25 |
| n21 | the small window swallows Alt-Shift-P | OV25 |
| n24 | the window blames ASE-L's option whoever put the data there | OV25, OV28, OV29 |
| n25 | the window calls a result chosen in the dialog the latest | OV11, OV18, OV25, OV27 |
| n26 | a finished run's plot is not recorded as the one that loaded | OV8, OV25 |
| n28 | a pasted copy keeps the version marks | OV21 |
| n29 | the cursor read-out names every version alike | OV23 |
| n30 | the Delete dialog names every version alike | OV23 |
| n31 | the Caps Lock form is bound whatever the key itself does | OV1 |
| n33 | a press that read the result and added nothing is not logged | OV23 |
| n34 | an undo point is taken in a tab the press did not change | OV23 |
| n35 | Reload's sentence counts the traces it takes out | OV7 |
| n36 | data of another day says no seconds | OP5 |
| n37 | a reload that read nothing does not put the trace highlights back | OV23 |
| n38 | the small window of the press before outlives the next press | OV25 |
| n40 | a file loaded beside the result is given the result's time | OV23 |
| n44 | the strips are not folded before the record a failed load is undone from | OV23 |
| n45 | the analysis a kept trace shows is not counted among the ones the window shows | OV20, OV27 |
| m3 | a kept copy the undo history is pinned to is unloaded | OV26 |
| m5 | Ctrl-R reads the analysis the session plots, whatever the waveforms show | OV27 |
| m6 | Ctrl-R second-guesses the analysis of the row the dialog chose | OV27 |
| m7 | a file typed into the viewer's Location bar leaves the pins on | OV26 |
| m8 | a file the engine refuses there leaves the pins off | OV26 |
| m9 | a saved copy of the run a trace is kept on counts as other data | OV28, OV17 |
| m11 | a finished run's keep leaves the versions of ASE-L's rows out | OV28 |
| m12 | the plot button reads a selected row as the analysis the session plots | OV27 |
| m13 | a Direct Plot does not say that it loaded | OV28 |
| m14 | the dialog's Loaded list has a row for the kept copy | OV26 |
| m15 | the Signal Browser is not told that a database was renamed or unloaded | OV26 |
| m17 | the small window names a saved result by its file | OV12, OV27 |
| m18 | nothing says that the analysis is the dialog's row's | OP6, OV27 |
| n22 | a key typed on the small window does not close it | OV8, OV25, OV29 |
| n23 | a modifier alone closes the small window | OV25, OV29 |
| n27 | a reload is not recorded as the one that loaded | OV25 |
| m1 | Tk's own Tab binding runs on the small window after it is gone | OV25, OV26, OV27, OV28, OV29, OV17, OV15 |
| m2 | a file state that is kept again gets a new name: `u` finds its data gone | OV29 |
| p1 | Ctrl-R does not read the result as the analysis ASE-L names when the file holds none of the analysis shown | OV29 |
| p2 | the second read of Ctrl-R asks for the analysis shown again | OV29 |
| p3 | the view on screen is matched with ASE-L's kept traces as they are pinned | OV29 |
| p4 | the stored views are matched with ASE-L's kept traces as they are pinned | OV29 |
| p5 | a kept row named as before the pin is not marked: its strip can count as the same strip | OP7, OV29 |
| p6 | a kept trace made by hand is named as before the pin too | OP7 |
| p7 | ASE-L's trace that is not kept is marked too | OP7 |
| p8 | the range of strip records is ignored | OP7 |
| p9 | Results > Select keeps a file state under a new name every time | OV29 |
| p10 | the overlay and a finished run keep the data in view under a new name every time | OV29 |
| p11 | a kept name that is still loaded is given again | OV18 |
| p12 | the second read of Ctrl-R is not recorded as the one that loaded | OV29 |
| p13 | the Super and Hyper keys are no modifiers | OP7, OV29 |
| p14 | AltGr and the group keys are no modifiers | OP7, OV29 |
| p15 | the lock keys are no modifiers | OP7 |
| p16 | Mode_switch and the compose key are no modifiers | OP7 |

## The builder's choices (not ruled by the user)

1. **Which trace takes the shade, and the shades.** The trace that is there keeps its
   colour and the new one takes the shade, as the request says. The shades go 40 % towards
   white, 35 % towards black, 65 % towards white, 60 % towards black, then again. So with
   three versions the newest is the darker one. `wviewer_overlay_shades` changes the list.
2. **A waveform that already has a trace on the result gets none.** Going back and forth
   between two results adds nothing twice.
3. **The pop-up is a small window that is not modal** (the tree has no modal message
   boxes: a grab stops every test that presses a key), it closes on any key, and it names
   the Auto Plot option only when a finished run's plot is why the waveforms are current.
4. **Ctrl-R and the plot button take the later versions out**, and a saved state holds
   one trace of each waveform: the earlier results live in memory only.
5. **The versions stay when another door loads; a waveform with one version follows.** A
   Direct Plot made after another run reads the new result. The versions of a waveform do
   not move to it. A waveform with a single trace does, as before this issue. Whether a
   Direct Plot should leave every waveform where it is, as a select now does, is open.
6. **Results > Select keeps ASE-L's own rows too**, not only the traces made by hand, and
   a trace that had no data stays empty.
7. **A file picked by path in the dialog** is read by Ctrl-R and Alt-Shift-P until the
   next run; the plot button plots the session's own result, as it always did.
8. **The analysis the waveforms show decides how the result's file is read.** An AC plot
   beside a session that plots its transient gets the new run's AC analysis.
9. **The legend cue**: a saved result's name, the day for data of another day; the cursor
   read-out and the Delete dialog carry it too, for the traces a finished run keeps (issue
   1765) as well.
10. **A File menu entry was added**, which the request did not ask for.
11. **Refused while a run of the session is live**, on Ctrl-R's terms.
12. **After a select, a finished run under Append, New SubWin or New Win** leaves the
    kept traces on the data they show.
13. **One analysis for the three gestures.** Ctrl-R, like the key, reads the analysis the
    waveforms show when they are all of another one than the session plots, unless the
    dialog chose the row; the plot button reads a saved result or the last run as the row
    the dialog chose. (Before, Ctrl-R and the plot button always read the analysis the
    session plots.)
14. **A file typed into the viewer's Location bar is loaded into every waveform**, the
    ones a finished run had kept on an earlier run included (issue 1765 left those where
    they were at such a load).
15. **A saved result is the same data as the run it was saved from**, told by the file's
    name, time and size: a trace kept on that run gets no second curve of it.

## Open

1. The user's ruling on the choices above, the fifth in particular.
2. The user's own look, on their screen and keyboard: whether Alt-Shift-P reaches the
   viewer through their X server, and whether the shades read as "slightly different" on
   their colours (owed look `overlay_latest_1780`).

## Known, and left

- A waveform with one version follows a load made by another door (choice 5).
- After a select, a finished run under Append, New SubWin or New Win leaves the kept
  traces (choice 12).
- A database the engine loaded by a door that takes no note (the schematic's Waves menu
  in a viewer context) is read again by the key even when it is the result, and the
  versions then show the same data twice.
- Two results written within one second with the same size are one file state.
- A tab that is not shown and loses its later versions (Ctrl-R) loses its trace
  highlights.
- `u` takes back the versions of the tab shown; the versions the same press added to
  another tab stay until Ctrl-R.
- A viewer with no data loaded at all has nothing to keep its traces on, so a select made
  then draws them.
- `test_wave_sigbrowser_keys` (not registered) is red on rows BK22, BK29 and BK31, at the
  commit before this change as well.
- A key the keymap gives no name closes the small window like any other key.

## Not checked

- The kept name of a file state kept again (`wviewer::held_name_new`) at its third
  caller, the keep of a database a trace names itself (a digital database attached with a
  run): no row.

- The user's own screen and keyboard. Every run here was on a hidden display under openbox.
- A real simulator run between two presses: the rows write the results file themselves.
- No row drives a rainbow graph, a digital (VCD) database, a visual that is not TrueColor,
  or a shade under the editor's selection dimming; the first review ran the first three and
  the last by hand and found nothing.
- The arm of `wviewer::select_keep_post` for a database that is already a kept one, the
  two returns of `wviewer::overlay_latest` for a refused context switch, a marker on a
  version that goes, the small window without Tk, and what a Plot Difference says about
  who loaded: no row.
- The Windows build.
