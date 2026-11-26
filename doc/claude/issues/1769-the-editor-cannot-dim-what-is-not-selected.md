# 1769 — the editor cannot dim what is not selected

**STAMP:** `v1 claim=fixed tree=da1e6b380 stamped=2026-11-26 fix=taken open=2 by=driver-1769`

Asked by the user on 2026-11-25 and built the same night. What is open is listed under
"Open".

## What the user wrote

> Let's add support for dimming in the schematic editor so people can easily see the
> selected object.
>
> An option can be set so that dimming is always enabled - that is, when an object is
> selected, it will gain prominence and everything else gets "dimmed". Through the menu,
> and, of course, through settings in the rc file that can be loaded, one can set how much
> dimming (default 30%) is applied. This will live commented out in cadence_style_rc and can
> be found through Command Palette as well. By default, dimming is NOT enabled. However, if
> Ctrl-Alt-Shift-D is used, it can toggle dimming ON/OFF.
>
> In addition, sometimes, through the action of other commands, some objects are selected -
> say a find command. Now, the user just wants to quickly locate that object visually. For
> this, she wants to turn ON and the OFF dimming quickly. For this, we support
> Alt-Shift-RMB_down to "dim" (different from enable dimming). Now, only the selected
> objects are displayed prominently, and the user can release the buttons and move on.

## What it was

Nothing of the kind existed. View > Dim colors dims or brightens the whole palette, the
selection with it, and stays until it is undone by hand.

## What was built

Spec: `doc/claude/specs/selection_dim.md`. FAQ Q111. Suite:
`tests/headless/test_selection_dim_1769.tcl`, registered on both arms.

| asked | built |
|---|---|
| an option that keeps dimming on | `selection_dim` (0 or 1). With it on, everything that is not selected is dimmed whenever something is selected |
| off by default | `set_ne selection_dim 0` |
| Ctrl-Alt-Shift-D toggles it | action `view.toggle_selection_dim`, a row of the built-in binding table; the status line says which way it went |
| the amount, default 30 %, by menu and rc file | `selection_dim_percent`; View > Dimming amount (10 % to 90 %, Other...) |
| the menu | View > Dim unselected objects (a check entry showing the key) |
| the Command Palette | "Dim unselected objects" and "Dimming amount" |
| commented out in `cadence_style_rc` | `# set selection_dim 1` and `# set selection_dim_percent 30`, with what each does |
| Alt-Shift-RMB down dims, release restores | action `view.selection_dim_peek`, a row of the binding table; it dims whatever the setting says |
| "say a find command" | a Find in its default mode highlights and selects nothing, so with nothing selected the peek brings out what is highlighted |

How it works, in three sentences. `draw()` paints a dim frame's document in two passes: what
is not selected with a second colour table (each layer's colour moved towards the
background) in the layer GCs, then what is selected with the layers' own colours back, and
the selection overlay on top. When an xschem command is done (every canvas event is one),
the frame is repainted if it is no longer the one wanted: plain or dim, for this selection,
at this amount. A painter of the document that runs outside `draw()` either brings the dim
colours in itself or is noticed, and the frame is repainted.

## Found on the way, and dealt with

- **Alt-Shift-RightButton was taken.** It was upstream's "cut the wire under the pointer,
  cut point not aligned to the snap grid". The chord now belongs to the peek, as asked. The
  cut keeps its menu entry (Tools > Break wires at mouse position) and its
  Super-Shift-RightButton chord, and `xschem unbind button 3 alt+shift canvas` gives it the
  Alt chord back. Rows `H6`, `H7`.
- **In the Cadence profile Ctrl-Alt-Shift-D would have plotted a difference.**
  `src/cadence_style_rc` binds `<Alt-Key-D>` (Alt-Shift-D, issue 1727), and a Tk sequence
  matches a key that carries more modifiers than it names. The profile now also carries a
  `<Control-Alt-Key-D>` line that hands the chord to the canvas. Rows `C1`, `C2`; row `GC1`
  of `test_ase_plot_difference_1727` follows (its "a further modifier does not stop the
  key" leg now uses Super, and a new leg says what Control does).
- **Two quick peeks.** Tk delivers the second press of a double click only as the
  double-click event, so the second of two quick Alt-Shift-RightButton presses did nothing.
  For this chord the double-click event runs the chord's binding. Rows `H5`, `H9`.
- **A redraw that never ended.** In the only-probes view a full redraw did not record that
  it had painted a plain frame, and the repaint asked for by the end-of-command check
  evaluated Tcl that ran xschem commands that asked for the repaint again. Both are closed:
  every full redraw records the look it painted, and the check runs before the command
  depth returns to zero and cannot start itself. Row `O1`.

## The review

Three reviewers read the first build (painting, input, what the user sees), and a second
agent tried each finding with a probe of its own. 17 findings, all 17 confirmed; three of
them were reported by two reviewers, which leaves the 14 below. 13 are fixed, each with a
row; one is left and listed under "Known, and left".

| # | finding | what was done | rows |
|---|---|---|---|
| 1 | an export made over a dim frame came out dim in part: net highlights and embedded graphs | a painter that joins a dim frame does not take an export for one | `X3`, `X4` |
| 2 | a selected picture, graph or filled shape was dimmed like everything else; so were a selected text and a selected instance's texts in the classic look | two passes: what is selected is painted in its own colours | `F5b`, `G2`, `P2` |
| 3 | the amount changed by a plain `set`, then a command that paints part of the frame: the rest stayed at the old amount | the frame's own percent is recorded; partial painters use it | `A3b` |
| 4 | a toggle repaints only the window it was given in | left: see "Known, and left" | |
| 5 | a wheel step while the peek is held ended it, and the release then opened the context menu | a press ends a stranded peek only when it carries the right button as up | `H4b` |
| 6 | the pointer leaving the canvas and coming back ended the peek | an entry proves nothing (it is handed over with a state of 0) and is no longer asked | `H4c` |
| 7 | in a waveform viewer Ctrl-Alt-Shift-D cleared the target strip | the viewer has a closer key line for the chord, for the capital typed with Caps Lock too; a viewer window is never dimmed | `W1`, `W2` |
| 8 | with `set selection_dim true` in an rc file the menu entry needed two clicks | a boolean word becomes 1 or 0 | `D7`, `M4` |
| 9 | with the wire tool left armed (the Cadence profile does that) the peek did nothing and said nothing | a bound chord is taken while a wire or shape is being drawn | `H4d`, `H4e` |
| 10 | a Find in its default mode highlights and selects nothing, so the request's own example got "nothing is selected" | with nothing selected the peek brings out the highlights | `H12` |
| 11 | the toggle's status message did not fit the status line | shortened | `T2` |
| 12 | View > Dimming amount wrote an unexpanded variable to the action log | each entry's command carries its amount; the setter logs the line that sets it again | `M3`, `Q4` |
| 13 | the suite did not prove the grid, a text and a pin marker dim, nor the overlays undimmed, nor an export guard | rows added | `U1` to `U4`, `X2` to `X4` |
| 14 | the manual page still gave Alt-Shift-RightButton to the wire cut | updated | `D6b` |

(Reported twice: 2, 7, and 5 with 6 as one finding.)

## The break table

89 single changes to the sources, each made in a copy of the tree, the suite run on both
arms, and the change taken out again (C changes with a rebuild before and after). 87 turned
rows red, or ended or stalled the suite. Two did not, and each is a change with nothing to
see:

- **22**: a painter that repairs part of a dim frame after the amount changed uses the new
  amount instead of the frame's. The whole frame is repainted at the new amount when the
  command is done, either way.
- **89**: the waveform viewer's key line for a server that gives the small keysym with Caps
  Lock on. The Tk here resolves that key to the capital's line, which break 88 covers; the
  line follows the convention of `wviewer::install_case_binds`.

| # | the one change | without a display | on a display |
|---|---|---|---|
| 1 | the setting is not asked: only the peek dims | green | `F2` `F3` `F3b` `F3c` `F5` `F5b` `F6` `F7` and 33 more |
| 2 | the peek is not asked: only the setting dims | green | `H8` `H9` `H12` |
| 3 | dim with nothing selected | green | `F1` `F6` `F7` `H11` `H12` `I3c` `X1` |
| 4 | an amount of 0 still counts as dim | green | `A2` |
| 5 | the only-probes view is dimmed on top | green | `O1` |
| 6 | a waveform viewer window is dimmed | green | `W2` |
| 7 | the peek does not bring out the highlights | green | `H12` |
| 8 | the setting alone dims around a highlight | green | `H12` `I3c` |
| 9 | the amount is not clamped at 100 | `D4` | `D4` |
| 10 | a word that is no number reads as 0, not the default | `D2` `D4` | `D2` `D4` |
| 11 | the colours move away from the background | green | `F3` `F3b` `F3c` `F5` `F5b` `F9` `A1` `A1b` and 22 more |
| 12 | the fill GC keeps the layer colour | green | `F3b` |
| 13 | the dim tables are not rebuilt for another amount | green | `A1` `A1b` `A3` `A3b` |
| 14 | build_colors() leaves the old dim tables standing | green | `A4` `O1` |
| 15 | a highlight colour of its own is not dimmed (the pixel) | green | `I5` |
| 16 | a highlight colour of its own is not dimmed (r,g,b) | green | `I5` |
| 17 | a painter outside draw() brings the dim colours in over a plain frame too | green | `H12` `I3` `I3b` `X3` |
| 18 | a painter that joins a dim frame takes an export for one | green | `X3` |
| 19 | the sync ignores undimmed strokes put into a dim frame | green | `I1` `I2` |
| 20 | the sync does not see the amount change | green | `A1` `A1b` `A3` `A3b` |
| 21 | the sync does not see the selection change | green | `F5` `F5b` |
| 22 | a partial painter paints at the amount as it reads now, not the frame's | green | green |
| 23 | the sync's repaint eats the command's result | green | the suite ended without a verdict |
| 24 | the toggle logs the flip, not the state reached | green | `T5` |
| 25 | the toggle says nothing about an empty selection | `T2` | `T2` |
| 26 | the peek says nothing when there is nothing to bring out | `H3` | `H3` |
| 27 | what is not selected is painted in the layers' own colours | green | `F3` `F3b` `F3c` `F5` `F5b` `F9` `A1` `A1b` and 18 more |
| 28 | what is selected is painted dim | green | `F5b` `G2` `P2` |
| 29 | the grid is painted before the dim colours are in | green | `H12` `U1` |
| 30 | the highlights and pin markers after the passes are in the layers' own colours | green | `I3` `I5` |
| 31 | in a peek around the highlights the highlights are dim too | green | `H12` |
| 32 | the pin markers are painted in the layers' own colours | green | `U3` |
| 33 | draw() leaves the dim colours in for the overlays | green | `pre` `F2` `F3` `F3b` `F8` `F9` `A1` `A1b` and 19 more |
| 34 | an export is dim | green | `X3` `X2` |
| 35 | a redraw limited to a bbox asks what is wanted now | green | `F9` |
| 36 | a full redraw does not record the selection it was painted for | green | `F5` `F5b` `F6` `A3` `A3b` `H8` `H10` `H12` and 5 more |
| 37 | a full redraw does not record the amount it was painted at | green | `F3` `F3b` `F3c` `F5` `F5b` `F6` `F9` `A1` and 27 more |
| 38 | a picture is not dimmed | green | `P1` |
| 39 | a highlight colour of its own is not dimmed through cairo | green | `I5` |
| 40 | a graph repainted on its own does not join the dim frame | green | `G1` |
| 41 | a selected graph repainted on its own is dimmed | green | `G2` |
| 42 | the passes do not sort the lines | green | `F3c` `F5b` `I2` |
| 43 | the passes do not sort the boxes | green | `F3b` `I2` |
| 44 | the passes do not sort the arcs | green | `F3c` |
| 45 | the passes do not sort the polygons | green | `F3c` |
| 46 | the passes do not sort the instances | green | `F3c` |
| 47 | the passes do not sort the wires | green | `F3` `F5` `F9` `A1` `A1b` `A3` `A3b` `A4` and 11 more |
| 48 | the passes do not sort the texts | green | `U2` |
| 49 | the passes do not sort the graphs | green | `G1` |
| 50 | the passes do not sort the pictures | green | `P1` |
| 51 | the primitives do not note a stroke into a dim frame | green | `I1` `I2` |
| 52 | the primitives note draw()'s own pass over what is selected | green | `F2` `F5` `F5b` `F6` `F9` `A3` `A3b` `A4` and 21 more |
| 53 | highlights stroked on their own do not join the dim frame | green | `A3b` `I3b` |
| 54 | a highlighted label's own colour is not dimmed | green | `I5` |
| 55 | a solid highlight stroke's own colour is not dimmed | green | `I5` |
| 56 | the frame is not synced when a command is done | green | `F2` `F3` `F3b` `F3c` `F5` `F5b` `F6` `F7` and 30 more |
| 57 | xschem set selection_dim does nothing | `T3` | `T3` |
| 58 | the peek's release is not taken: it stays held | `H1` `H2` `H3` `H4b` `H4c` `H4d` `H5` | the suite stalled (a context menu or a cut that nothing answers) |
| 59 | the peek's release ends it but goes on to the context menu | green | the suite stalled (a context menu or a cut that nothing answers) |
| 60 | a release that never comes leaves the peek on | `H4` | `H4` |
| 61 | a press of another button does not end a stranded peek | `H4` | `H4` |
| 62 | any press ends the peek, a wheel step with the right button down included | `H4b` | `H4b` |
| 63 | the pointer coming back into the canvas ends the peek | `H4c` | `H4c` |
| 64 | the second of two quick presses is not a peek | `H4d` `H5` | the suite stalled (a context menu or a cut that nothing answers) |
| 65 | Alt-Shift-RightButton does not ask the binding table: it cuts | `H1` `H3` `H4` `H4b` `H4c` `H4d` `H4e` `H6` and 1 more | the suite stalled (a context menu or a cut that nothing answers) |
| 66 | with the chord unbound nothing cuts | `H6` `H7` | `H6` `H7` |
| 67 | the peek is refused while a wire is being drawn | `H4d` | `H4d` |
| 68 | the key's row is not in the built-in table | `B2` | `B2` |
| 69 | the peek's row is not in the built-in table | `B2` | `B2` |
| 70 | the key is on Ctrl-Alt-d, without the Shift | `B2` `K2` | `B2` `K2` |
| 71 | the Tcl default amount is 50 | `D1` | `D1` |
| 72 | the setting is on by default | `D1` | `D1` |
| 73 | the menu entry flips twice | green | `M2` `M4` |
| 74 | the amount setter takes anything that is a number | the suite ended without a verdict | the suite ended without a verdict |
| 75 | the amount setter keeps fractions | `Q1` | `Q1` |
| 76 | the amount setter refuses silently | `Q3` | `Q3` |
| 77 | the amount setter writes nothing to the action log | green | `Q4` |
| 78 | the amount menu stops at 50 | green | `M3` |
| 79 | an amount entry's command names the variable, not the amount | green | `M3` |
| 80 | a boolean word written to the setting is left as written | green | `M4` |
| 81 | the peek row of actions.csv carries a command | `B3` | `B3` |
| 82 | the Cadence profile sets the dimming on | `D5` | `D5` |
| 83 | the Cadence profile lacks the Control-Alt line | green | `C2` |
| 84 | the shipped key file lacks the row | `B2` | `B2` |
| 85 | keys.help does not name the key | `D6` | `D6` |
| 86 | the manual page does not name the key | `D6b` | `D6b` |
| 87 | the waveform viewer lacks its closer key line | green | `W1` |
| 88 | the waveform viewer lacks the Caps Lock forms of its key line | green | `W1` |
| 89 | the waveform viewer lacks the small-letter Caps Lock form | green | green |

## Builder's choices, for the user to rule on

1. **What "30 %" means.** Every colour moves 30 % of the way to the background colour, so
   100 % makes what is not selected disappear. The other reading (what is not selected is
   shown at 30 % strength) would be this scale's 70.
2. **Alt-Shift-RightButton leaves the unaligned wire cut** (above).
3. **Everything that is not selected dims**, net highlights, pin markers, embedded graphs
   and pictures and the grid included. What is selected keeps its own colours; the selection
   overlay, the hover outline and the crosshair are not dimmed.
4. **With nothing selected the setting dims nothing. The peek then brings out what is
   highlighted**, because a Find in its default mode highlights; with nothing highlighted
   either, the status line says so.
5. **The peek ends when the right button comes up**, whether Alt and Shift are still down
   or not, and that release opens no context menu.
6. **The setting is not remembered between sessions** except through an rc file, like the
   Selection look.
7. **The names:** `selection_dim`, `selection_dim_percent`; View > Dim unselected objects,
   View > Dimming amount.
8. **Exports are never dimmed.**
9. **The Cadence profile gets one more key line** (`<Control-Alt-Key-D>`, above), and the
   waveform viewer one (`<Control-Alt-Shift-Key-D>`).
10. **A change of the selection repaints a dim frame**, once, because what is selected is
    painted in its own colours. A full redraw of a 117-instance example took 3.5 ms on the
    hidden display.
11. **A waveform viewer window is never dimmed.**

## Open

- The user's rulings on the eleven choices above (owed-ledger rule `1769`).
- The user's own look on a real screen (owed-ledger look `selection_dim_1769`): every run
  here was on a hidden display.

## Known, and left

- **Another window follows when the pointer enters it** (review finding 4). The setting is
  one for all windows, but the frame repainted when it changes is the current window's.
  Repainting the others means switching the editor's context to each, the mechanism of
  issue 0848; the colour scheme and the Selection look behave the same way today.
- **Classic Selection look.** It paints the selection in the grid layer's grey over the
  object, with the dim on as with it off.
- **Not TrueColor.** On such a visual a net highlight style with a colour of its own is not
  dimmed.
- **Upstream, seen while testing, not touched:** leaving the only-probes view leaves every
  layer a shade brighter until the colours are next built (`draw()` ends that view's frame
  with `build_colors(1.0, 0)`); `xschem undo` after a wire cut does not repaint the cut's
  cue; `xschem draw_hilight_net 1` paints a highlighted label's letters over themselves.
  Each was measured in a clone of the commit before this change.

## Not checked

- A real screen and pointer.
- The Windows build and a build without cairo: neither is built here.
- The picture of an embedded graph inside a PDF or PostScript export: that writer is compiled
  only with libjpeg, which this build lacks. It is the same guarded call as the SVG's.
