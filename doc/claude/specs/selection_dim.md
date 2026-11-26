# Selection dim: dim what is not selected

Issue 1769. The user's request of 2026-11-25: "add support for dimming in the schematic
editor so people can easily see the selected object".

Rows named here are in `tests/headless/test_selection_dim_1769.tcl`.

## What the user gets

- **The setting, `selection_dim` (0 or 1, default 0).** With it on, as soon as anything is
  selected, everything that is not selected is painted in colours moved towards the
  background colour. With nothing selected the schematic looks as it always does.
- **The amount, `selection_dim_percent` (0 to 100, default 30).** How far the colours move:
  0 is no change, 100 is the background colour itself. A word that is no number means 30.
- **The toggle.** Ctrl-Alt-Shift-D, View > Dim unselected objects, the Command Palette
  ("Dim unselected objects"), `xschem toggle_selection_dim`. The status line says which way
  it went, and, when it went on with nothing selected, that it shows with the next
  selection.
- **The amount's doors.** View > Dimming amount (10 % to 90 % and Other...), the Command
  Palette ("Dimming amount"), `selection_dim_percent_set <n>`, or `set
  selection_dim_percent <n>` in an rc file or the CIW.
- **The peek.** Holding Alt-Shift-RightButton dims while the button is down, whatever the
  setting says; releasing it puts the frame back. It brings out the selection. With nothing
  selected it brings out what is highlighted instead (a Find in its default Highlight mode
  highlights what it finds and selects nothing). With neither, the status line says so and
  the frame does not change.
- **In an rc file:** `set selection_dim 1` and `set selection_dim_percent 30`.
  `src/cadence_style_rc` carries both commented out.

## What is dimmed and what is not

Dimmed: everything that is not selected, on every layer but the background: shapes, wires,
symbols, texts, the grid, embedded graphs and pictures (a picture is painted that much more
transparent), net highlights (a style with a colour of its own included) and pin markers.
Rows `F3`, `F3b`, `F3c`, `I3`, `I5`, `G1`, `P1`, `U1`, `U2`, `U3`.

Not dimmed: what is selected, which is painted in its own colours under the selection
overlay (rows `F5b`, `G2`, `P2`); the selection overlay in every Selection look (`L1`); the
hover outline and the crosshair (`U4`). In a peek with nothing selected, the highlights
(`H12`).

Never dimmed: exports (rows `X1` to `X4`), the only-probes view (`O1`), a waveform viewer
window (`W2`).

## Rules

- **R1. The frame follows the selection.** After every xschem command, and so after every
  canvas event (each arrives as `xschem callback`), the frame in the window is the one
  wanted: plain, or dim for the selection as it is now and at the amount as it reads now. A
  change of any of these costs one full redraw; a pointer motion costs none (rows `F2`,
  `F5`, `F6`, `A1`, `N1`, `N2`). `sel_dim_sync()` in `src/xinit.c`, called from `xschem()`
  in `src/scheduler.c` before the command depth returns to zero.
- **R2. Two passes, inside `draw()`.** A dim frame's document is painted twice over: what is
  not selected with the dim colour table in the layer GCs, `color_index[]` and
  `xcolor_array[]`, then what is selected with the layers' own colours back
  (`sel_dim_apply()`, `SEL_DIM_SKIP()`). The grid before, and the net highlights and pin
  markers after, are dim. Outside `draw()` the GCs hold the layers' own colours, so no
  other painter has to know about the feature.
- **R3. A painter of the document that runs outside `draw()` joins the frame.**
  `draw_hilight_net()` and `draw_graph()` bring the dim colours in themselves over a dim
  frame (`sel_dim_enter()`, `sel_dim_leave()`), with the percent the frame was painted at.
  Any other one (a shape placed by a command) is noticed by the drawing primitives
  (`SEL_DIM_NOTE()` in `src/xschem.h`: a paint into the backing pixmap of a dim frame with
  the dim colours not in) and the frame is repainted when the command is done. Rows `I1` to
  `I7`, `A3b`.
- **R4. A redraw limited to a bbox keeps the look of the frame it repairs**, as it keeps the
  selection style. Row `F9`.
- **R5. Exports are never dim**, and a painter that joins a dim frame does not take an
  export for one (`sel_dim_export`). The window's frame is repainted after an export that
  painted into its backing pixmap.
- **R6. The peek ends with its button.** The right button's release ends it whatever is
  still held and is nothing else (no context menu). A release that never arrives (the button
  came up over another window) is made up for by the next button press or pointer motion
  that carries the right button as up. A wheel step with the button down, and the pointer
  leaving the canvas and coming back, leave the peek alone. Rows `H1`, `H2`, `H4`, `H4b`,
  `H4c`, `H8`, `H9`.
- **R7. Two quick peeks are two peeks.** Tk delivers the second press of a double click
  only as the double-click event; for this chord that event runs the chord's binding. Rows
  `H5`, `H9`.
- **R8. The peek works while a wire or a shape is being drawn.** It changes nothing in the
  document, and the Cadence profile leaves the wire tool armed after every wire. Row `H4d`.
- **R9. The command's result survives.** The repaint of R1 runs Tcl; the result of the
  command that caused it is put back. Row `F7`.

## Bindings

Both are rows of the built-in binding table (`init_input_bindings()` in `src/callback.c`,
mirrored in `src/keybindings.csv` and `src/mousebindings.csv`), so `xschem bind` and
`xschem unbind` move them:

| chord | action |
|---|---|
| key `D` with ctrl+alt (Ctrl-Alt-Shift-D) | `view.toggle_selection_dim` |
| button 3 with shift+alt | `view.selection_dim_peek` |

**Alt-Shift-RightButton was upstream's "cut the wire under the pointer, cut point not
aligned to the snap grid".** The hard-coded branch in `handle_button_press()` now asks the
binding table first, so the peek's row is what took the chord. The cut keeps its menu entry
(Tools > Break wires at mouse position) and its Super-Shift-RightButton chord, and
`xschem unbind button 3 alt+shift canvas` gives it the Alt chord back. Rows `H6`, `H7`.

**Two Tk sequences would take Ctrl-Alt-Shift-D first**, since a Tk sequence matches a key
that carries more modifiers than it names. Each has a closer match beside it:

- `src/cadence_style_rc` binds `<Alt-Key-D>` (Alt-Shift-D, plot a difference) and now also
  `<Control-Alt-Key-D>`, which hands the key to the canvas. Rows `C1`, `C2`.
- The waveform viewer binds `<Control-Shift-Key-D>` (clear the target strip) and now also
  `<Control-Alt-Shift-Key-D>`, which flips the editor's setting and clears nothing. Row `W1`.

## Introspection

- `xschem get selection_dim`: `wanted drawn applied hold percent built selected stale`.
  `wanted` and `drawn` are 0 (plain), 1 (dim around the selection) or 2 (dim around the
  highlights).
- `xschem get selection_dim_color <layer>`: the colour that layer is painted in inside a dim
  draw, `#rrggbb`.
- `xschem set selection_dim <0|1>`: the absolute form of the toggle, and what the toggle
  writes to the action log. `selection_dim_percent_set <n>` writes itself there.

## Known, and left

- **Another window follows when the pointer enters it.** The setting is one for all windows,
  but the frame that is repainted when it changes is the current window's. Another window
  side by side keeps its frame until the pointer enters it (a tab is repainted when it is
  switched to). The colour scheme and the Selection look behave the same way.
- **The classic Selection look** paints the selection in the grid layer's grey over the
  object, with the dim on as with it off.
- **Not TrueColor.** On such a visual a net highlight style with a colour of its own is not
  dimmed (a pixel there is an index and says nothing about its colour).
