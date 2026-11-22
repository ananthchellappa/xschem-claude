# Work order 03b — a key typed over the viewer acts as a viewer key, whichever window has the keyboard

Written 2026-11-21 at night by the lead, after item 03's first run. It follows item 03
and builds on its commit.

## Why this item exists

The user: "In the waveform viewer, I'd like to use Ctrl-Shift-M to toggle single/multi plot
mode (what Ctrl-Shift-4 in linked schematic window does). But, I get a 'View is Read Only'
popup".

Item 03 made the chord work, and closed its whole family, for a key that arrives at the
viewer's plot canvas: that is, when the plot has the keyboard focus. Its crews then found
a second way to the same popup which that change cannot see, measured with real
server-side keys on the test display:

- **The keyboard focus is in a schematic window and the pointer rests over a viewer's
  plot** (after Alt-Tab, a click on the task bar, or simply because the user clicked in
  the schematic last). The key is delivered to the schematic window's canvas, whose
  binding hands it to the engine; the engine's current context is the viewer's, because
  the pointer entered it; so the key runs in the viewer as the schematic command it is.
  Ctrl-Shift-M brings up "View is Read Only". In the Cadence profile `s`, `w` and bare
  `b` bring up the same box; Alt-b steps hide-symbols.
- **Right after a viewer opens**, the focus is on the viewer's toplevel (every viewer key
  does nothing) or still in the schematic window (the case above). One click in the plot
  ends both.

Rows KM14 and G1f of `tests/headless/test_wave_viewer.tcl` hold these two as declared
limits, and the guide and `doc/claude/specs/waveform_viewer.md` state them.

The user's own first try is exactly this: open a viewer, move the pointer in, press the
chord. Work order 03 told its crews that the chord need only work where the viewer's
other chords work (its "decided by the lead", point 4). The lead withdraws that point: it
leaves the reported popup standing. The user has not ruled on this; the receipt lists it.

The first run's full result, with what was measured in this state and the three ways out
its crews listed, is
`/home/analog/dev/xschem-claude/doc/claude/overnight_batch_2026_11_21/receipts/03_viewer-ctrl-shift-m.run1.json`
(read only; see the two `rule` entries under `debts` that speak of the keyboard focus).

## What the user gets

1. With the pointer over a viewer's plot, a key does what it does when the plot has the
   focus, whichever window of this xschem holds the keyboard: the viewer's own chords run
   (Ctrl-Shift-M flips the plot mode), graph keys go to the graph, everything else does
   nothing. Never the popup, never an editor verb.
2. Right after a viewer opens, the same, without a click.
3. With the pointer over a schematic window nothing changes for that window.

## How

The crew measures first and decides the details; this is the shape.

- **The door is in the engine.** `callback()` (`src/callback.c`) is handed a key event by
  the binding of the window that has the focus, while the current context is a viewer's.
  A guard there, for a key press or release whose window is not the current context's
  canvas while the context carries the viewer flag (`xschem set wave_viewer 1`; search
  `wave_viewer` in `src/`), hands the key to the viewer in Tcl and does not run the
  editor's key handling.
- **In Tcl, do what Tk would have done** had the key been delivered to the viewer's
  canvas: first the filter (`wviewer::key_filter`), with the pointer's pixel in that
  canvas; then the viewer's own chord, if one is bound for this key on the `WaveViewer`
  tag, where a user's rc binding wins and the Caps Lock dispatch of
  `wviewer::install_case_binds` applies. Tk cannot be asked to deliver a key to a window
  that lacks the focus (`event generate` sends a key to the focus window, which is how
  this would loop), so the match has to be made by the receiving proc. It reads
  `bind WaveViewer` itself; it does not keep a second list of the viewer's chords. Its
  choice is fenced by parity with real delivery (row 5).
- **The keyboard focus is not moved by a key.** Taking it for the viewer would leave the
  schematic's keys dead when the pointer goes back there.
- **After an open**, give the plot canvas the viewer toplevel's focus (plain `focus`, not
  `-force`), so that when the window manager activates the new window its keys reach the
  filter. If you bind keys on the viewer's toplevel instead or as well, the binding acts
  only when the event's window is the toplevel itself: a binding on a toplevel also fires
  for every widget inside it, and a key typed into the Signal Browser's search box must
  stay there.
- The filter forwards a graph key to the engine with the viewer's canvas as its window:
  the guard lets that through.

## Decided by the lead (spec holes; the receipt lists them for the user)

1. The pointer decides, as it does everywhere else in xschem, and the key works; it is
   not merely dropped.
2. A key release follows its press.
3. The mirror state is unchanged: with the focus on a viewer's plot and the pointer over
   a schematic window, the filter swallows the key, as today. State it as a limit and
   return a `rule` debt.
4. A key typed in a window that is not an xschem drawing window (ASE-L's window, the
   Calculator, the results window, the Signal Browser's panes and search box) stays
   there, as today. Show it with a row for the search box.
5. No new chord, and no change to what any key does when the plot has the focus.

## Rows (red today unless marked)

Item 03's crews sent real server-side keys and pointer moves (XTEST) in their probes; the
scripts are named in the evidence fields of the result file above, and
`tests/headless/wvkey_engine.tcl` is the helper their rows use. Where a registered suite
cannot put the focus in one window and the pointer in another with real events, enter the
viewer with a real pointer move and call the engine's own entry for the key, with the
schematic's canvas as its window; say which rows do which.

1. Focus in the schematic window, pointer over strip 0 of a viewer: Ctrl-Shift-M flips
   the plot mode; the status bar follows; one log line; no message box.
2. Same state, the editor keys that reached the engine: `w`, and in the Cadence profile
   `s` and bare `b`, Alt-b, Ctrl-Alt-s, Ctrl-Alt-t: nothing happens. No box, no form, no
   window, no wire, hide-symbols unmoved. Send the three that open something only after
   the change, bounded, as work order 03 says.
3. Same state, graph keys act on the graph: a bare `b` toggles cursor B; `m` on a trace
   makes one marker. In both profiles.
4. After an open and without a click, in each focus state the display can give: the
   chord flips the mode.
5. Parity: for every sequence bound on the `WaveViewer` tag, read from `bind WaveViewer`,
   and for a user's rc binding added for the row, the script the receiving proc chooses
   is the one Tk runs for the real event with the focus on the canvas (recorders on
   both). A riding count; the Caps Lock variants included.
6. Controls, green today: with the pointer over the schematic window and the focus there,
   keys act on the schematic as before, with one viewer open and with two. With two
   viewers, a key goes to the one under the pointer.
7. An ordinary second schematic window: the focus in the first, the pointer over the
   second. Whatever each key of the family does today, it does after the change (take
   the answers BEFORE you change anything). The guard is for viewer contexts only.
8. The focus in the Signal Browser's search box, the pointer over the plot: the typed
   character goes into the box and the plot gets nothing.
9. A key release in the state of row 1.
10. Restated, not deleted: KM14 and G1f.

## Two riders left by item 03 (added by the lead 2026-11-22, when item 03 landed)

Item 03 is in this clone's base as its own commit; its receipt is
`doc/claude/overnight_batch_2026_11_21/receipts/03_viewer-ctrl-shift-m.md` (section 5,
"Left open"). Two small things it left are in the code this item works in. The user asks
that siblings of one cause be cured in the same pass. Both are small: if either cannot be
finished and shown red-first inside the first build, leave it out, say so, and return it
as a debt. Neither may hold up rows 1 to 10.

11. **The chord with exactly one cursor showing** (a row only; the product is right).
    A break that makes Ctrl-Shift-M dead while cursor A alone or cursor B alone shows
    passes every suite: the rows press it with no cursor and with both. Add the leg to
    SWK19 of `tests/headless/test_wave_subwindows.tcl` (the cursor state answered as A
    only, as B only, as both) and show it red under that break on both arms.
12. **A middle-button drag near a strip's edge at a high Tk scaling.**
    `wviewer::btn2_filter` asks `wviewer::strip_at_pixel_inset` with its fixed default of
    8 pixels, while the engine's border inside a graph grows with the Tk scaling
    (`wviewer::graph_border_px`, which item 03 added for the keys and row SWK25 holds
    against `src/callback.c`). Measured in item 03's first run at scaling 2.0: a
    middle-button press 9 pixels inside a strip is not taken by the graph and pans the
    viewer's schematic canvas, the gesture issue 0149 removed from this window. The
    inset the button filter uses must be no smaller than the engine's border at the
    display's scaling; where 8 pixels suffice today nothing may change (take the answers
    before you change anything). A row at scaling 2.0 through the recorder SWK25 uses,
    red today.

## Texts to update

The guide (`doc/waveform_viewer_guide.html`): the note in its section on keys that says a
click is needed, and its troubleshooting row. `doc/claude/specs/waveform_viewer.md`: its
limits. `doc/claude/specs/waveform_viewer_modes.md`. The header of `src/wave_viewer.tcl`
and the headers of rows KM14 and G1f. A comment above the guard in `src/callback.c` that
says why it is there and for which contexts. A new entry on top of `doc/claude/FAQ.md`.

## Traps

- A C change: C89, and `make -C src` before any suite is evidence. The quiz's proofs
  quote lines of `waves_callback` and one binding-table row: do not reformat them.
- `callback()` writes the pointer position into the context for every event, above its
  switch (issue 1659), from the event's own coordinates, which here belong to ANOTHER
  window. Where the guard stands relative to that write decides whether the viewer's
  stored pointer is spoiled. Compute the pixel for the filter in Tcl from the pointer and
  the canvas's place on the screen, and check it at a Tk scaling other than 1.
- Under the tabbed interface `xschem get current_win_path` is a context path, not always
  a Tk widget path. Resolve the canvas through `xschem windows`
  (`doc/claude/TEST_LESSONS.md`).
- A context switch rewrites a viewer's title (issue 0173). This path must switch nothing.
- The engine is re-entered: the guard calls Tcl, and the filter calls the engine again
  for a graph key. Mind the semaphore the engine keeps.
- Only `test_wave_viewer` replaces `tk_messageBox` with a recorder; a red-first row
  anywhere else pops a real modal on the unchanged product.
- The user's Windows X server cannot be measured here. Where the focus lands after an
  open depends on the desktop: return a `look` debt that says exactly what to try.

## Out of scope

Routing of mouse buttons and the wheel (they are delivered to the window under the
pointer; rider 12 changes only the inset of the middle-button filter). The Signal
Browser's own keys. The mirror state of decision 3.

## Done means

Rows 1 to 10 green on the arm each belongs to, each new row shown red on the unchanged
product, the two limits gone from the guide and the spec, and the debts returned. Riders
11 and 12 done, or returned as debts with the reason.
