# Work order 03 — Ctrl-Shift-M in the waveform viewer toggles the plot mode, and no viewer key reaches the editor

Prepared 2026-11-21.

## The request

The user: "In the waveform viewer, I'd like to use Ctrl-Shift-M to toggle single/multi plot
mode (what Ctrl-Shift-4 in linked schematic window does). But, I get a 'View is Read Only'
popup".

The user works in the Cadence profile (`src/cadence_style_rc`, which sets `cadence_compat`).

## What the user gets

1. In a waveform viewer window, Ctrl-Shift-M flips single/multi plot mode of the TARGET
   subwindow, exactly as Options > Plot Mode and Ctrl-Shift-4 on the design window do
   (rule SW22 of `doc/claude/specs/waveform_viewer_subwindows.md`). The status bar follows,
   one action-log line is written, no popup appears.
2. No key pressed in a viewer window reaches `readonly_block()` or any other editor verb,
   in the Cadence profile and in the stock one. The reported popup is one member of a
   family (below); the family is the scope.

## What is true today

Read from the code on 2026-11-21 at `7c77f3594` by a scout, not run. Full notes:
`/home/analog/dev/xschem-claude/doc/claude/overnight_batch_2026_11_21/maps/03_viewer-ctrl-shift-m.map.json`
(read only). A skeptic's corrections, if any, are at the foot of this work order. Your
first job is to REPRODUCE the popup and each family row on the private display; a row of
the family that does not behave as written is a finding, and the tree wins.

- The viewer's canvas has one key binding, `wviewer::key_filter`, installed by
  `wviewer::strip_bindings`. It forwards a key to the C engine when its keysym is in the
  namespace variable `graphkeys` and `wviewer::over_graph` answers yes; the only modifier
  carve-outs are Ctrl-d and Ctrl-b. It never `break`s.
- Ctrl-Shift-M: keysym M is in `graphkeys`, so it is forwarded as
  `xschem callback <win> 2 x y 77 0 0 5`. In `handle_key_press()` (`src/callback.c`),
  `case 'M'`, the plain-Shift arm asks `waves_selected()` first (the measurement tooltip);
  the Control arm opens with `readonly_block()`. The viewer's buffer is read-only for
  life, so the popup comes up.
- Nothing binds the chord on the `WaveViewer` bindtag (`wviewer::install_default_binds`,
  `wviewer::install_case_binds`).
- Plot mode: `wviewer::set_plot_mode invert <token>` already flips the target subwindow,
  refreshes the status bar and logs. There is no `..._at %W` wrapper for it. The menu
  entry has no accelerator.

## The family (close it in this pass)

Cause: the filter allows by KEYSYM; the engine then decides again by key, modifiers,
profile and its own geometry, and several of its arms for an allowed keysym are editor
verbs with no graph guard. By reading, with the pointer over a strip:

| chord | reaches today |
|-------|---------------|
| Ctrl-Shift-M (also Caps Lock + Ctrl-m) | `readonly_block()`: the reported popup |
| plain `s`, Cadence profile | `readonly_block()` (the guide says `s` swaps the cursors) |
| Alt-s / Super-s | "reload from disk?" prompt, then a reload of the viewer's buffer |
| Ctrl-Alt-s | the Save-as-symbol form |
| Ctrl-Alt-t | a new schematic window |
| Alt-b / Super-b | cycles hide-symbols |
| Alt-m / Super-m | arms a move in the viewer's context, with no popup (m and d are forwarded inside `wviewer::with_edit`, which lifts read-only) |
| any graph key in the few pixels just inside a strip's edge, or with `graph_use_ctrl_key` set | the engine's own "over a graph" test disagrees with the filter's and the canvas arm runs (inferred, not measured) |
| a user's own binding-table row for a forwarded chord | runs from the viewer |

Measure each before you rely on it. A sibling with the same cause that is not in the
table is in scope too.

## Decided by the lead (spec holes; the receipt lists them for the user)

1. **The whole family is closed, not only M**, and closed silently: a chord the viewer
   does not use does nothing. That is the viewer's own stated design (the header of
   `src/wave_viewer.tcl`: everything else is silently swallowed).
2. **`s` in the Cadence profile swaps the cursors in a viewer**, as the guide says. A graph
   embedded in an ordinary schematic keeps today's behaviour in both profiles: this item
   does not change what any key does outside a viewer window. Fence that with a row.
3. **Target subwindow**, not the one under the pointer (SW22).
4. **Focus:** the chord works where the viewer's other chords work (the plot area has the
   focus). The Signal Browser panes are not changed.
5. **The menu shows the key:** `Ctrl+Shift+M` as the accelerator of the Options > Plot Mode
   entry, and a row in the guide's key table.
6. **`graph_use_ctrl_key` set** (not the user's profile, not the default): the viewer takes
   Ctrl-Shift-M for the plot mode. Say so where `doc/claude/specs/graph_markers.md` says
   the tooltip key has no collision in either mode.
7. **No new tip-of-the-day question** (the quiz's "Waveform viewer" topic is at its cap).

## How

Required shape, in Tcl:

- A wrapper in the house form (`wviewer::clear_all_at` is the model) that resolves the
  token from `%W`, answers `{}` for a canvas that is not a viewer's, and calls
  `wviewer::set_plot_mode invert`.
- The default binding as a literal `bind WaveViewer <Control-Shift-Key-M> {...; break}` in
  `wviewer::install_default_binds`, guarded like its neighbours so a user's rc binding
  wins. The Caps Lock ruling of 2026-10-16 applies: `wviewer::case_pairs` gains the
  letter, so Caps Lock + Ctrl-m is the same chord.
- The forward decision of `wviewer::key_filter` becomes a decision by CHORD: a pure proc
  of (case-mapped keysym, modifier state), no Tk, that answers yes only for chords whose
  engine arm goes to the graph. Derive its table from the engine's arms and state it in
  one place. `graphkeys` stays as it is.

For what Tcl cannot decide (plain `s` under `cadence_compat`; the edge band; a profile or
a user row that reroutes a forwarded chord), add the smallest change in C that makes the
family table's rows true FOR A VIEWER CONTEXT ONLY. The context already carries a flag
for this (`xschem set wave_viewer 1`; search `wave_viewer` in `src/`). Choose between a
guard on the individual arms and one guard ahead of the editor's key switch after you
have measured which suites send keys into a viewer context through `xschem callback`
directly; Escape and whatever else the filter forwards on purpose must keep working. Say
which you chose and why. If the C part cannot be made safe tonight, land the Tcl part,
leave `s` and the edge band as named limits with rows that hold today's answer out of the
gate (not as passing rows), and say so: the user's own chord must not wait for it.

## Rows (red today unless marked)

Put the real-key rows in `tests/headless/test_wave_viewer.tcl` (in `dcases`; the one
registered suite that replaces `tk_messageBox` with a recorder, and has the `ca_send`
helper that sends a `<Motion>` first and gives the key its coordinates). Put the pure and
census rows where both arms run (`test_wave_subwindows`, `test_wave_grid`).

1. Display: a real Ctrl-Shift-M over strip 0. Separate legs: the filter saw keysym M with
   Control and Shift; no message box; the plot mode flipped; the status bar says so; one
   `wviewer::set_plot_mode` log line; the measurement-tooltip flag did not move. A second
   press flips back.
2. Display, controls that must stay as they are (green today): Shift-M toggles the
   tooltip and leaves the mode alone; Ctrl-m and bare `m` over a trace each create one
   marker.
3. Display, two subwindows: the chord flips the target subwindow only; after a click in
   the other subwindow it flips that one.
4. Display, the Caps Lock matrix for `m` at the four Control states, with the wrapper
   replaced by a recorder.
5. Counted: the wrapper's `info args`; it answers `{}` for an unknown path without
   raising; `case_pairs` holds the letter.
6. Counted: the chord decision as a matrix over every member of `graphkeys` and the
   modifier states (none, Shift, Control, Control-Shift, Alt, Control-Alt, Super, and the
   Caps Lock variants), compared with a table derived from the engine's arms. A riding
   count, and a leg that says how many chords are forwarded so the row cannot go empty.
   The must-refuse legs are the family table.
7. Cadence profile, in a viewer: `s` over a strip swaps the cursors and pops nothing.
   And the fence for decision 2: in an ordinary schematic with an embedded graph, each
   key of the family does today exactly what it did before, in both profiles (take the
   answers BEFORE you change anything).
8. Census: the guide's key row, the bind statement and the menu accelerator agree in both
   directions (rows GH0 to GH4 of `test_wave_grid` do this; the count literals they and
   two other suites hold move in the same change).

Do NOT drive the dangerous siblings through real dispatch on the unchanged product: with
the message-box recorder answering "ok", Alt-s reloads the viewer's buffer and destroys
the fixture; Ctrl-Alt-s opens a modal form that nothing dismisses; Ctrl-Alt-t opens a
window. Show those red through the decision (recorders on `xschem callback` and
`wviewer::over_graph`, the shape of row SWK18), and green through real dispatch only
after the change, bounded.

## Texts to update

`doc/waveform_viewer_guide.html` (the mode section, the key table, the Caps Lock note);
`doc/ase_l_tutorial.html` (the viewer's Options line); the specs
`waveform_viewer_modes.md` (D7, the menu section), `waveform_viewer_subwindows.md` (SW22,
the keys section and the sentence that quotes the census figures),
`waveform_viewer.md` (what the filter forwards), `graph_markers.md` (the `M` row);
issue 0186's sentence that a reload is not reachable from the viewer's keyboard (a dated
note); the header prose of `src/wave_viewer.tcl` and the comments of the procs you touch.
Grep for others.

## Traps

- The class binding alone does not fix the popup: the filter runs first, forwards to the
  engine and does not break. Without the refusal one key press would pop the box AND flip
  the mode.
- Only `test_wave_viewer` records message boxes. A red-first row for this chord anywhere
  else pops a real modal on today's tree and stalls until the watchdog.
- `event generate <Alt-Key-s>` does not set Mod1 in Tk; give the state explicitly.
- Rows GH1 and GH2 scan `install_default_binds` for the literal `bind WaveViewer <seq>`
  text, and GH3 needs `-label {X} -accelerator Y` on one source line. The quiz suite's
  proofs quote existing `bind WaveViewer` lines verbatim: do not reformat those.
- `tests/headless/test_wave_sigbrowser_keys.tcl` (in no list, but run by `full_audit.sh`)
  matches the exact text of the filter's present forward expression and evaluates it.
  Keep that line or move those rows in the same change, and take its baseline first: one
  of its rows was red in the private tree before any of this.
- `install_default_binds` runs once per session; a suite that opened a viewer before
  your binding existed in that process will not see it.
- `m` and `d` are forwarded with read-only lifted, so a refusal for them has to happen in
  Tcl before the forward.
- `test_wave_markers` has the most rows on these keys, is in no list, and times out
  (issue 1488). It is not the fence for this item.
- A C edit needs `make -C src` before any suite is evidence.

## Out of scope

The Signal Browser's own keys; any change to what a key does over a graph embedded in a
schematic; the Ctrl-Shift-4 binding on the design window.

## Done means

Rows 1 to 8 green on the arm each belongs to, each new row shown red on the unchanged
product (or, for the dangerous siblings, through the decision), the family table true
after the change as measured, and the texts above saying what the code does.
