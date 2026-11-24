# 1727 — Plot the difference of two nets from the schematic (Alt-Shift-D)

**STAMP:** `v1 claim=fixed tree=73f73e686 stamped=2026-11-23 fix=taken open=3 by=crew-plotdiff`

A feature request, built. Measured on the tree above and with the build on it, on a private
Xvfb with openbox. Built by the commit that adds this file. Spec:
`doc/claude/specs/ase_l.md`, "Plot the difference of two nets" (rules R-PD1 to R-PD11).
Suite: `tests/headless/test_ase_plot_difference_1727.tcl`, registered on both arms.

## The request

The user, 2026-11-23, three messages, verbatim:

1. *"In Cadence, I had set up Alt-Shift-D to plot a difference. It would ask me to click on
   one, then another (status bar prompt message) and then, when it had two, it would plot the
   difference of 2nd minus 1st."*
2. *"It will work in the schematic, so, what the Waveform Viewer is currently showing is
   irrelevant. But, it's a good point. If there is ONLY ONE analysis in ASE-L, for which a
   difference of signals makes sense, then, yes, we can support that analysis. However, if
   TRAN is ONE of the analyses that was run in the loaded result, then Alt-Shift-D should
   default to that."*
3. *"The catch - the user, looking at how this is realized in the bind command in the
   cadence_style_rc, should be easily able to make a custom shortcut for DC or AC analysis.
   It's just that it's most frequently going to be used only for TRAN, like in my past
   Cadence life."*

## What those words rule

- **R1.** One command, started from the schematic window by Alt-Shift-D in
  `src/cadence_style_rc`. It asks for a first net and then a second, each with a status-bar
  prompt, and when it has two it plots SECOND MINUS FIRST in the waveform viewer of the
  ASE-L session.
- **R2.** It works from the schematic. What the waveform viewer is showing plays no part in
  which analysis is read.
- **R3.** The analyses that count are those that were run in the loaded result of the
  session and from which the difference of two node voltages can be plotted as a wave: the
  transient, AC, the DC sweep; not the operating point. Alt-Shift-D reads the transient when
  the loaded result has one. When it has none and exactly one of the others, that one is
  read.
- **R4.** The bind line in `src/cadence_style_rc` is what a user reads to make a shortcut of
  their own for AC or for the DC sweep. That must be possible from the line and the comment
  above it alone.

## The driver's choices — not yet ruled by the user

Each of these was chosen by the driver of the build, was built as written, and is waiting
for the user's word.

- **C1** (driver's choice, not yet ruled by the user). The command is
  `ase::plot_difference_for_current ?analysis?`, beside `ase::direct_plot_for_current`. The
  word is ASE-L's own for the analysis: `tran`, `ac`, `dc`; with none, the transient. The
  word's analysis is read when the loaded result has it. When it has not and the result
  holds exactly one of the three, that one is read instead. In every other case the command
  refuses in one sentence naming the analyses the result holds, and plots nothing. The
  Alt-Shift-D line carries the transient's word; two commented example lines under it carry
  AC and the DC sweep on chords the profile does not use.
- **C2** (driver's choice, not yet ruled by the user). The prompts are on the status line
  Direct Plot's prompt uses and name the analysis read: first the request for the first
  net; then the first net's name, the request for the second, and that the plot is the
  second minus the first. When another analysis is read than the word's, the user is told
  which, at entry.
- **C3** (driver's choice, not yet ruled by the user). One shot: the second net plots at
  once and ends the mode, with no ESC. ESC before that cancels, says so, plots nothing.
- **C4** (driver's choice, not yet ruled by the user). The trace is the one the Calculator
  plots for the difference text, through its translator and its plot, so the legend, a
  saved session, a reload and a re-run treat it as any Calculator expression trace. The
  destination is Direct Plot's, not the Calculator's own setting.
- **C5** (driver's choice, not yet ruled by the user). A click that is not one named net
  gets a sentence saying what was clicked and what to click instead, and the mode stays on
  the same step.
- **C6** (driver's choice, not yet ruled by the user). A pick is hierarchy-qualified as
  Direct Plot's, the session is found as Direct Plot finds it, and the two nets may be
  picked at different depths.
- **C7** (driver's choice, not yet ruled by the user). No session, no loaded result, or a
  net the loaded result does not hold: a sentence naming the cure. A net that is not in
  the result is refused at its own click.
- **C8** (driver's choice, not yet ruled by the user). AC is correct or refused.
- **C9** (driver's choice, not yet ruled by the user). No menu entry, dialog, toolbar
  button, or key outside the Cadence profile; nothing changed in Direct Plot, the
  Calculator window or the viewer; voltages of nets only.
- **C10** (driver's choice, not yet ruled by the user). The key works in the windows and
  tabs Ctrl-4 works in, by the same mechanism.

## What was built

**The command and the choice of analysis** (`src/ase.tcl`).
`ase::plot_difference_for_current ?analysis?`; `ase::diff_functions` (the three analyses and
the Calculator's voltage function for each, read off `calc::pick_analyses`);
`ase::diff_analysis` (pure: the analyses the result holds and the word in, the analysis or
a refusal out); `ase::diff_names` (the names an analysis of the results file holds, from
the file's header); `ase::diff_text` (the Calculator text of the difference).

**The mode** (`src/ase_window.tcl`). Select On Design in a third flavour, `diff`:
`ase::ui::plot_difference` enters it through `ase::ui::select_on_design`, whose seize,
prompt slot, pause across a descend and release it uses as they are. `ase::ui::pd_pick`
says what a click is, `ase::ui::pd_click` moves the mode, `ase::ui::pd_finish` plots, and
`ase::ui::pd_msg` holds every sentence of the status line.
`ase::ui::sod_click` hands a click of this flavour to `pd_click`; `ase::ui::sod_end` hands
its end to `ase::ui::pd_end`; `ase::ui::sod_slots` lets the release of the last click end
the mode. `ase::ui::dp_dest` is now the one place Direct Plot's destination is written,
read by Direct Plot and by this.

**The Calculator** (`src/calculator.tcl`): `calc::analysis_of_plot`, the reading of one
`Plotname:` record, lifted out of `calc::raw_analyses` so both read a record the same way.

**The profile** (`src/cadence_style_rc`): the Alt-Shift-D line, its comment, and the two
commented example lines.

### Measured, and decided on the measurement

- **Without the profile the three chords do nothing** (row GN1: no editor state moves, no
  mode, no grab, no binding). So the profile's line displaces no key.
- **AC (C8).** On the fixture's AC pair, two nodes that differ in phase at every point, the
  Calculator's translation of `vf(b) - vf(a)` answers the difference of the two magnitude
  columns, which is not the magnitude of the difference of the two voltages (row PT5 holds
  both numbers). The engine can form the right one: the real and imaginary part of each
  voltage from its magnitude and phase columns (`re()`, `im()`), subtracted, squared,
  summed and rooted. That postfix is the AC text, it goes through the same translator and
  the same plot, and rows PT5, GU2, GU3 and GF2 compare what is plotted with the complex
  difference computed in the row from the numbers the row wrote. **AC is in the
  population.** The cost: for AC the text is not `vf(second) - vf(first)`, which C4's
  wording would have it be.
- **A prompt longer than the status bar has room for was never seen.** The second prompt,
  written whole into the slot of a window whose size nobody had set, made the window grow,
  the canvas was resized, the engine blanked the slot on that event, and the timer wrote
  the prompt again: a loop, with the slot blank whenever it was read. `src/xschem.tcl`
  (`pack_widgets`) records the same growth for the readout beside the slot. So this
  flavour's prompt is cut to the room the slot has on every write (`ase::ui::pd_fit`);
  rows GK3 and GP1.
- **In a window nobody sized, the cut took the words that mattered** (found by the review
  of the first build). The red field beside the slot holds the short form of a notice
  whenever the CIW is not in front of the user, and the room that leaves is a little more
  than the first prompt needs. The second prompt named the first net first and lost "second
  minus first" to the cut; a refusal described the click first and lost what to click
  instead. So every sentence but the first prompt now opens with the request
  (`ase::ui::pd_msg`), and band GQ reads those words off the slot itself, with the red
  field holding a line, for the transient and for the DC sweep, whose name is the longest.
  The first build's rows compared the whole sentence with the mode's record, which no
  window cuts.
- **A second load of the same data would blank the first difference.** Direct Plot loads
  the results again at every plot, and a load drops every vector an expression trace was
  computed into (issue 1734, open). A difference is an expression trace, so plotting it
  Direct Plot's way would have made each difference blank the one before. `pd_finish`
  loads only when the viewer does not already draw from that very result read as that
  analysis (`ase::ui::pd_shown`); row GS2. **That covers one case only**: a difference
  that reads another analysis than the viewer shows, or the same analysis after the
  results file changed, does load, and the differences plotted before it then have no
  data (rows GU4 and GS3 read their values).
- **The results file can change between the two clicks.** The analysis is chosen when the
  key is pressed. Written again without that analysis before the second click (a run that
  ends while the mode is up), the file was handed to the viewer all the same: its load
  answered yes, left the viewer with no data, and the Calculator's refusal that followed
  ended in the middle of a sentence. `pd_finish` now asks the file again which analyses it
  holds before anything is loaded, and says which it holds and to press the key again;
  row GT2.

### Decisions the work order did not cover

1. **The bind sequence names the capital letter with Alt and no Shift.** With Shift held
   the letter key types the capital, and with Caps Lock on Alt alone types it; naming Shift
   would make the key dead under Caps Lock. This is the rule the profile already has for
   Shift-X (the user's ruling of 2026-10-16: the case of the letter as typed decides).
   Rejected: naming Shift as the Alt-Shift-C line does, and a dispatcher proc as `q` has,
   which a user could not copy from one line. Row GC1.
2. **A word that is none of the three is refused, whatever the result holds.** Read by the
   one rule it would be "an analysis the result does not hold" and fall back to the one
   analysis present, so a mistyped word on a user's own line would plot something. Row PA7.
3. **The word is read in any letter case.** Row PA8.
4. **A refusal becomes the prompt** until the next click, and is also said in the CIW. The
   Calculator's selectors do the same on this slot. Rejected: the CIW alone, which a user
   looking at the schematic may not be reading. **It says what to click instead before it
   says what was clicked**, the other way round from the Calculator's selectors, because
   the slot may show the beginning of the sentence only (R-PD9).
5. **Empty space is refused with a sentence.** Direct Plot is silent there; the work order
   lists empty space among the clicks that get one.
6. **What is under the cursor is asked at the cursor itself**, as the Calculator's voltage
   selector asks, not at the snapped point Direct Plot's net pick uses (issue 1303).
7. **The names a click is asked against are read once, at entry.** A run that finishes
   while the mode is up is seen by the plot, not by the next click.
8. **The viewer is switched to the analysis read** when it shows another, as Direct Plot
   switches it to the session's own analysis at every plot. That is how R2 is met with a
   viewer that shows one analysis at a time.
9. **Nothing is coloured on the schematic** for the two nets, and the trace carries the
   viewer's own name for an expression, as any Calculator trace does.
10. **The second prompt reads `click second net (second minus first); first net <name>;
    ESC cancels`.** C2 lists the first net's name before the request. The name has no
    bound, and in a window nobody sized the slot ends a few letters after the first
    prompt would, so the request and the words "second minus first" come first and the
    name after them; "the" is dropped before "second net" because with it the words did
    not fit beside the transient's and the DC sweep's heads. Rejected: `2nd minus 1st`
    (the user's own phrase, shorter, but two spellings of one word in one sentence), a
    shorter head (it is the head of every sentence and of the CIW's notices), and naming
    the first net inside the request (`plots it minus <name>`: the words asked for are
    then not on the slot).
11. **What stops the plot after the second click names a cure** (R-PD11): the first build
    had two such sentences with none and one with "try again". Where the cure is not
    certain the sentence says what is known: a viewer that cannot be switched to the
    results is one that a run or another command holds, so "when it has finished"; a plot
    that raises says to press the key again and to report the line if it repeats.

## How it was checked (2026-11-23, private Xvfb with openbox, through `run_suites.sh`)

**Red first.** The suite as committed, run against the product files of the tree above
(`src/ase.tcl`, `src/ase_window.tcl`, `src/calculator.tcl`, `src/cadence_style_rc` and the
spec): every row of every band is red there except the fixture rows and the rows that
assert an absence or an end state (FX1 to FX3, GN0, GN2, PN3, the second leg of PT5, GK6,
GK8, GK11, GO4, the bus-dialog leg of GR1, GR4, GS0, GD8, GU1, GL2 and the two fixture legs
of PC5 and PE5).

**Breaks of the product**, each built, run on both arms and put back; the rows named are
the ones that went red.

| break | red without a window | red with one |
|---|---|---|
| more than one wave analysis and none the word's: the first is read | PA3 PA5 PE1 | the same, GF3 |
| the names of the file's first plot, whatever analysis is asked | PN1 | PN1 |
| one refusal sentence reworded | PM2 | PM2 GR1 GR2 GL1 |
| the spec names a row that is not one | PX1 | PX1 |
| the difference reversed (first minus second) | PT1 PT3 PT4 | the same, GK4 GK5 GK6 GK10 GO3 GR3 GS2 GD2 GD7 GU2 GV1 |
| the AC text is the plain difference of the two `vf()` | PT2 PT3 PT5 | the same, GU2 GU3 GF2 |
| the first net again is not refused | PC3 PC5 | the same, GR2 GR3 GD5 GD6 GD7 |
| no results file is not refused where it is | PE3 | PE3 GE1 |
| the mode ends inside the second net's press | none | GO1 |
| a cancelled mode says nothing | none | GX1 GX2 |
| a bus is not refused as a bus | PC2 | PC2 GR1 |
| the prompt is written whole, never cut to the slot | none | GK3 GR1 GR2 GD1 GD6 GU2 GP1 |
| the results are loaded again at every difference | none | GS2 |
| the profile's sequence names Shift | PR1 | PR1 GN1 GC1 GW1 |
| the first net's notice goes to the CIW pane only | none | GL1 |
| a pick is not qualified by its level | PC5 | PC5 GD2 GD4 GD5 GD6 GD7 |
| the viewer is never loaded again once it holds anything | none | GV1 GF2 |
| the fall-back is taken and not said | none | GF1 |
| the profile has no example lines | PR2 PR3 | PR2 PR3 GN1 GU0 GU2, band GU aborts |
| Alt-Shift-D has a native action (a row of `src/keybindings.csv`) | none | GN1 |
| the difference lands as a Replace | none | GS1 GV1 |
| the flavour's first prompt is not written | none | GK2 GF1 GU2 |
| no session: nothing is said | PE5 | PE5 GE2 |
| the word is read as typed, case and all | PA8 | PA8 |
| a net the analysis does not hold is not refused at its click | PC1 PC2 | PC1 PC2 GR1 GR2 GR3 |

**Not reddened by any break built**, in the first build or in the repair round below: PA1,
PA2, PA4, PA6, PA7, PC4, PM3, PN2, PE2, PE4, GK1, GK7, GK9, GO2, GD3, GH2 (each is red on the
unchanged product), and the fixture rows.

### The repair round (2026-11-23, after the review of the first build)

Every finding of the review was taken; none was refuted. What changed, and the rows that
hold it:

- **The fixture had one kind of click.** Every net was picked on the middle of a wire and
  the only devices were a resistor and a block. The top sheet now has a voltage source
  with one pin on a wire and one bare, and a net label that is clicked on its own text.
  Row PC0 says what each new point is by the engine's and Direct Plot's own rules; rows
  PC1, PC2, GK12, GK13, GR1 and GR2 click them.
- **The key outside the profile.** Row GN1 now reads every binding tag of the canvas for
  the three letters before the profile is sourced and requires that a press says nothing;
  row PR4 reads every text file of `src/` for a line that names the command.
- **The analysis the session has enabled** (row GM1), **the pointer resting on a pin**
  (row GH1), **the slot itself in a window nobody sized** (rows GQ1 to GQ4), **what stops
  the plot after the second click** (rows GT1 to GT8, PE6), **an earlier difference after
  another analysis or changed results** (rows GU4, GS3), **the log as a trajectory** (row
  GL2: the gesture adds comment lines and no other line), **the audit's list** (row PX2).
- **The product**: the order of the sentences (`ase::ui::pd_msg`), the second look at the
  results file and the cures (`ase::ui::pd_finish`, `ase::ui::pd_end`,
  `ase::ui::plot_difference`). Nothing else in the product moved.
- **The texts**: the guide's note and its two paragraphs on where a plot lands, FAQ Q100,
  the tutorial's quoted sentences, the spec (R-PD1 to R-PD4, R-PD6, R-PD9, R-PD10, a new
  R-PD11), and this file.

**Red first.** The suite as it stands, against the four product files of the tree above:
every row is red except FX1 to FX3, GN0, GN2, PN3, the second leg of PT5, PC0, GK6, GK8,
GK11, GQ0, GQ5, GO4, the bus-dialog leg of GR1, GR4, GS0, GD8, GU1, GM2, GT9, the fixture
legs of PC5 and PE5, and PX1 and PX2, which read the spec and the audit's list. Against the
first build's product, before this round's product change: PM1, PM2, PE6, GK3, GQ2, GQ3,
GQ4, GR1, GR2, GL1, GD1, GD5, GD6, GU2, GT2, GT4, GT5, GT6 and GP1 were red.

**Breaks of the product in this round**, each built, run and put back; the rows named are
the ones that went red.

| break | red without a window | red with one |
|---|---|---|
| a click applies Direct Plot's source rule: a source's body is taken | PC2 | PC2 GQ3 GR1 GR2 GR3 |
| a click applies Direct Plot's pin rule first: a wire's end on a pin is the pin | PC1 | PC1 GK12 GK13 |
| a net is resolved for a wire only: a net label is not a net | PC1 | PC1 GK12 GR2 |
| the stock bindings bind the capital D with Alt to the command | PR4 | PR4 GN1 GW1 |
| a menu entry in `src/xschem.tcl` runs the command | PR4 | PR4 |
| the analysis the session has enabled is read when the result holds it | none | GM1 |
| the prompt of this flavour names the pin under the pointer, as Direct Plot's does | none | GH1 |
| the first prompt is longer than the slot of an unsized window | not run | PM1 GK2 GQ1 GH1 GM1 GF1 GU2 |
| the results file gone at the plot is not refused | not run | GT1 |
| the Calculator's refusal of the plot is not said | not run | GT3 |
| the translator's refusal of the text is not said | not run | GT8 |
| a click whose reading raises ends the mode in silence | not run | GT7 |
| a click writes a command line into the action log | not run | GL2 |
| the viewer is never loaded again once it has loaded | not run | GF2 GS3 GT5 GU2 GU3 GU4 GV1 |
| the results file's time and size play no part in "the same data" | not run | GS3 GT5 |
| the results file is not asked again before the plot | not run | GT2 |
| the suite is not on the audit's list | PX2 | not run |
| the sentence builder gains a kind the rows do not hold to the order | PM3 | not run |

**The room, measured** (private Xvfb, the design window at the size its widgets ask for,
TkDefaultFont as that display resolves it): with the red field holding the short form of
the mode's own notice the slot has room for 480 pixels of text for the transient and 475
for AC and the DC sweep; without it, 660. `click the second net (second minus first)`
after the transient's head measures 475 and the cut mark 14, so it did not fit; the
opening words that were built, `click second net (second minus first)`, measure 448 with
that head and 455 with the DC sweep's. These are one display's numbers; band GQ is what
re-checks the outcome.

### The gate's repair (2026-11-23, after the full regression of the built branch)

The full regression came back with one case off zero, on both arms:
`test_ase_saved_results_1705`, row SVR-D1. No row of this feature's own suite was red and
no product file was wrong: a fence of issue 1705 had two new procs to classify, and the
build had not run that suite.

- **What the row is.** Issue 1705 lets a session view a saved result instead of its last
  run (results_selection.md §20). Row SVR-D1 reads the Tcl sources R913 lists for every
  proc that names one of the procs answering for a run's files, and requires each to be in
  the suite's own table as a reader (it must follow the result in view), a writer (it must
  never), a listing proc or neither. `ase::ui::plot_difference` and
  `ase::ui::pd_finish` name `ase::last_rawfile`, the second `ase::last_vcdfiles` as well,
  and were not in the table.
- **The class: both are readers.** Each takes the results file from `ase::last_rawfile`,
  and `pd_finish` the VCDs from `ase::last_vcdfiles`; those two answer for the result in
  view, and neither proc writes a file of a run. It is the class the table gives Direct
  Plot's `ase::ui::dp_finish`. So "the loaded result" of R3 is the result the session is
  viewing: its last run, or a saved result while one is selected.
- **Measured, by a probe and not by a row.** On the 1705 suite's fixture (a run saved
  under a name, then the live run written again with other values), on the arm without a
  window, with the viewer's open (`wviewer::open`), `ase::ui::pd_shown`,
  `calc::raw_analyses` and `wviewer::attach_raw` replaced by stand-ins, the last two
  reporting the file they are handed: on the live view both procs asked the live run's
  results file, and `pd_finish` handed that file and the live run's VCDs to the viewer's
  load; with the saved result selected, the saved folder's file and its VCDs; back on the
  live view, the live ones again.
- **The break.** Both procs made to take the results file, and `pd_finish` the VCDs, from
  the session's own state and not from the view: SVR-D1 went red on both arms and named
  both procs in its reader leg. Classified "neither", that break would have passed. Put
  back; the suite is green on both arms.
- **What changed.** Two entries in the table of
  `tests/headless/test_ase_saved_results_1705.tcl`; a line in R913's table of
  results_selection.md; two sentences in R-PD2 of ase_l.md; a lesson in
  `doc/claude/TEST_LESSONS.md` §5; this section and one limit below. No product file
  moved.
- **Seen in issue 1705's fence and not repaired.** SVR-D1 finds a proc by the names R913
  lists, and `ase::live_rawfile` is not one the row looks for: with
  `ase::ui::plot_difference` rewritten to ask `ase::live_rawfile`, the proc matched
  nothing, left the row's population, and the suite stayed green (measured on the arm
  without a window; put back). R913 also lists `session_state` among the names that make a
  proc a caller, and the row's pattern does not hold it.

## Limits

- **While the session views a saved result** (issue 1705) the difference is read from
  that result. The viewer is switched to it by the load Direct Plot uses
  (`wviewer::attach_raw`), which results_selection.md §20 records as clearing the other
  results loaded in the viewer (its SVR48, not built). No row of either suite plots a
  difference under a saved view; what is held is the classification above.
- **A Direct Plot, a re-run, or a difference read from another analysis blanks the
  difference traces already plotted** (issue 1734, older than this, not repaired here).
  Each stays in its strip with nothing drawn. A second difference leaves the first one
  drawing only when it reads the same analysis of the same, unchanged results file (row
  GS2). The AC or DC-sweep key after Alt-Shift-D, Alt-Shift-D after one of them, a
  fall-back to another analysis, and Alt-Shift-D after the results changed all load the
  results and blank the earlier differences (rows GU4 and GS3).
- The status line shows the beginning of a sentence where it has no room for all of it.
  In a window narrower than the one nobody sized, or with a wider font, the cut can fall
  inside the request itself; the CIW has every sentence whole.
- The trace's legend entry is the viewer's name for an expression, not the two nets.
- Voltages of nets only: no current, no device pin, no bus difference bit by bit.
- A net the run did not save is refused; nothing is added to the session's outputs.

## Outstanding: 3

1. The user's rulings on C1 to C10 and on the decisions listed above.
2. A look on the user's own screen: the physical chord (with and without Caps Lock), the
   prompts on the status line at the user's window width and in the user's font (the
   second prompt and a refusal, with the CIW closed: are the request and "second minus
   first" on the line?), and the trace in the viewer. No row can see pixels, and every key
   here was a generated key on a hidden display.
3. One run of the suite on `:0` (Xwayland).
