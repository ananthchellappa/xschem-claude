# Work order 03 — Ctrl-Shift-M in the waveform viewer toggles the plot mode, and no viewer key reaches the editor

Prepared 2026-11-21; revised the same night after a second reader, told to refute the
scout's notes, checked them against the tree. This text already carries its corrections.

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

Read from the code on 2026-11-21 at `7c77f3594`, not run. The scout's notes and the
second reader's answer are
`/home/analog/dev/xschem-claude/doc/claude/overnight_batch_2026_11_21/maps/03_viewer-ctrl-shift-m.map.json`
and `.check.json` beside it (read only). Your first job is to REPRODUCE the popup and each
family row on the private display; a row that does not behave as written is a finding,
and the tree wins.

- The viewer's canvas has one key binding, `wviewer::key_filter`, installed by
  `wviewer::strip_bindings`. It forwards a key to the C engine when its keysym is in the
  namespace variable `graphkeys` and `wviewer::over_graph` answers yes; the only modifier
  carve-outs are Ctrl-d and Ctrl-b, and they test one state bit. It never `break`s.
- Ctrl-Shift-M: keysym M is in `graphkeys`, so it is forwarded. In `handle_key_press()`
  (`src/callback.c`), `case 'M'`, the plain-Shift arm asks `waves_selected()` first (the
  measurement tooltip); the Control arm opens with `readonly_block()`. The viewer's
  buffer is read-only for life, so the popup comes up.
- Nothing binds the chord on the `WaveViewer` bindtag (`wviewer::install_default_binds`,
  `wviewer::install_case_binds`).
- Plot mode: `wviewer::set_plot_mode invert <token>` already flips the target subwindow,
  refreshes the status bar and logs. There is no `..._at %W` wrapper for it. The entry
  lives in a nested submenu of Options and its label changes with the mode; it has no
  accelerator.
- The house recipe for a new viewer key is written down:
  `doc/claude/code_analysis/waveform_subsystem_reference.md`, the bullet on a new viewer
  key (issue 0171), with its test rules.

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
5. **The key in the menu.** Show `Ctrl+Shift+M` on the Options > Plot Mode entry only if
   the census can follow it: row GH4 of `tests/headless/test_wave_grid.tcl` forces a guide
   pair for every accelerator, and row GH6 looks each pair up in the LIVE menubar through
   `gh_find_entry`, which walks only the top-level cascades and compares fixed labels, so
   a pair for this nested, relabelled entry reddens GH6 as the suite stands. Either teach
   `gh_find_entry` to descend into cascades and make its label leg hold across the
   relabel, in the same change, or ship no accelerator and give the guide a key row
   without a menu pair (the shape the rows for `u` and `9` have). Take the second if the
   first is not small, and say which you took.
6. **`graph_use_ctrl_key` set** (not the user's profile, not the default): the viewer takes
   Ctrl-Shift-M for the plot mode, unconditionally. The two-pane Signal Browser spec
   declined to condition its Ctrl-b carve-out on that variable and declared the price as
   a limit; follow it. Correct the sentence in `doc/claude/specs/graph_markers.md` that
   says the tooltip key has no collision in either mode.
7. **Extra modifiers.** Tk runs a binding when the event carries more modifiers than the
   binding names, so Ctrl-Alt-Shift-M will run the new default, as Ctrl-Alt-D already
   runs Clear All. Accepted; say so in the spec.
8. **No echo line.** The chord is as quiet in the command window as the menu entry is; the
   status bar shows the mode. (Ctrl-Shift-4 on the design window echoes, because nothing
   else there shows it.)
9. **No new tip-of-the-day question** (the quiz's "Waveform viewer" topic is at its cap).

## How

Tcl only, unless a measurement shows a row cannot be made true that way.

- A wrapper in the house form (`wviewer::clear_all_at` is the model) that resolves the
  token from `%W`, answers `{}` for a canvas that is not a viewer's, and calls
  `wviewer::set_plot_mode invert`.
- The default binding as a literal `bind WaveViewer <Control-Shift-Key-M> {...; break}` in
  `wviewer::install_default_binds`, guarded like its neighbours so a user's rc binding
  wins. The Caps Lock ruling of 2026-10-16 applies: `wviewer::case_pairs` gains the
  letter, so Caps Lock + Ctrl-m is the same chord. It is the first row there with no
  lower-case base; check that `wviewer::case_key` and `wviewer::install_case_binds` take
  it.
- The forward decision of `wviewer::key_filter` becomes a decision by CHORD: a pure proc
  of (case-mapped keysym, modifier state), no Tk. It reduces the state the way
  `callback()` does before it decides (Num Lock and Caps Lock dropped, the bits above the
  modifier range dropped, then Shift and Button-1 for the reduced state), or Num Lock
  breaks it: today's gate tests single bits and is Num Lock proof. By reading, the engine
  sends a key to the graph only when the reduced state is empty (every member of
  `graphkeys`; `s` only outside the Cadence profile) or exactly Control (a, s, m, t, A,
  B; never b, d, M). Derive the table from the engine's arms yourself and state it in
  one place. `graphkeys` stays as it is.
- The edge band: gate the forward on `wviewer::strip_at_pixel_inset` with the key event's
  own pixel instead of, or as well as, `wviewer::over_graph`. That proc was written for
  this border and `wviewer::btn2_filter` already uses it; the filter receives the event's
  `%x %y`, the same pixel the engine tests.
- Plain `s` in the Cadence profile: by reading, forwarding it as Control-s reaches the
  same swap arm (the table has a graph row for it and the swap arm does not test
  Control). It needs the inset gate, because off a graph Control-s is Save. Measure it.

If one of these cannot be made to work, the fallback is the smallest guard in C that
applies to a viewer context only (the context carries a flag: `xschem set wave_viewer 1`;
search `wave_viewer` in `src/`). Then: do not reformat the marker arms of
`waves_callback` or the binding-table row for `d` (the quiz's proofs quote them),
rebuild before any suite, and say why Tcl was not enough.

## Rows (red today unless marked)

Real-key rows go in `tests/headless/test_wave_viewer.tcl` (in `dcases`): it is the one
registered suite that replaces `tk_messageBox` with a recorder, and its `send_key` takes
the event's coordinates (`ca_send` sends a `<Motion>` first). The helpers of the other
viewer suites have other signatures; do not paste across. Pure and census rows go where
both arms run (`test_wave_subwindows`, `test_wave_grid`).

1. Display: a real Ctrl-Shift-M over strip 0. Separate legs: the filter saw keysym M with
   Control and Shift; no message box; the plot mode flipped; the status bar says so; one
   `wviewer::set_plot_mode` log line; the measurement-tooltip flag did not move
   (`xschem get graph_flags`). A second press flips back.
2. Display, controls that must stay as they are (green today): Shift-M toggles the
   tooltip and leaves the mode alone; Ctrl-m and bare `m` over a trace each create one
   marker.
3. Display, two subwindows: the chord flips the target subwindow only; after a click in
   the other subwindow it flips that one. In `test_wave_subwindows` nothing records
   message boxes: on the unchanged product this row pops a real modal. Show it red in
   `test_wave_viewer`, or stub the box first.
4. Display, the Caps Lock matrix for `m` at the four Control states. In
   `test_wave_subwindows` the matrix sends keys with no coordinates, so the event pixel
   is the window's corner: with the real engine behind it, Ctrl-m there can arm a move in
   the fixture viewer for the rest of the suite. Run the `m` legs with `xschem callback`
   replaced by a recorder (the shape of row SWK18), and add the new wrapper to the
   suite's hand-kept recorder list or the matrix flips the real mode.
5. Counted: the wrapper's `info args`; it answers `{}` for an unknown path without
   raising; `case_pairs` holds the letter.
6. Counted: the chord decision as a matrix over every member of `graphkeys` and the
   modifier states: none, Shift, Control, Control-Shift, Alt, Control-Alt, Super, the
   Caps Lock variants, and Num Lock on top of each (states 16, 17, 20, 21) and a
   Button-1 bit. Compared with a table derived from the engine's arms. A riding count,
   and a leg that says how many chords are forwarded so the row cannot go empty. The
   must-refuse legs are the family table.
7. Cadence profile, in a viewer: `s` over a strip swaps the cursors and pops nothing. Its
   red-first form is safe through real dispatch in `test_wave_viewer` (the engine's arm
   stops at the popup, which the recorder counts). Setting `cadence_compat` turns
   `autotrim_wires` on through a write trace: save and restore both.
8. The fence for decision 2: in an ordinary schematic with an embedded graph, each key
   of the family does today exactly what it did before, in both profiles (take the
   answers BEFORE you change anything).
9. Census: the guide's key row and the bind statement agree in both directions (rows GH0
   to GH6 of `test_wave_grid`; GH5 and GH6 read the live window). The count literals
   move in the same change in FOUR suites: GH0 of `test_wave_grid`, BT09 of
   `test_wave_sigbrowser`, BK10 of `test_wave_sigbrowser_keys` and BX13 of
   `test_wave_sigbrowser_i12` (the last two are in no list but run under `full_audit.sh`,
   and both match the text of `test_wave_grid`'s own literals).

Do NOT drive the dangerous siblings through real dispatch on the unchanged product: with
the message-box recorder answering "ok", Alt-s reloads the viewer's buffer and destroys
the fixture; Ctrl-Alt-s opens a modal form that nothing dismisses; Ctrl-Alt-t opens a
window. Show those red through the decision (recorders on `xschem callback` and on the
graph test), and green through real dispatch only after the change, bounded. Tk's
`<Alt-Key-s>` pattern does not set Mod1: give the state explicitly.

## Texts to update

- `doc/waveform_viewer_guide.html`: the mode section; the key table; the Caps Lock note
  and its letter list; the table of the commands each key calls in the section on
  rebinding, where the new wrapper belongs.
- `src/cadence_style_rc`: its section of viewer keys holds a commented remap recipe per
  chord, and the guide says that file carries one for each; the new chord needs its own.
- `doc/ase_l_tutorial.html`: the viewer's Options line.
- Specs: `waveform_viewer_modes.md` (D7, the menu section), `waveform_viewer_subwindows.md`
  (SW22, the keys section, the Caps Lock paragraph's letter list, the sentence that
  quotes the census figures), `waveform_viewer.md` (what the filter forwards),
  `graph_markers.md` (the `M` row and the collision sentence).
- `doc/claude/code_analysis/waveform_subsystem_reference.md`: the recipe, now that the
  filter decides by chord.
- Issue 0186: a dated note on its sentence that a reload cannot be reached from the
  viewer's keyboard.
- `src/wave_viewer.tcl`: its header prose on how the mode is changed and on what the
  filter lets through; the comments of the procs you touch; a comment there says the
  engine has no getter for the graph flags, and it has one.
- Hand-kept lists the change touches: the name of row SWK8 and the sabotage ledger in
  the header of `tests/headless/test_wave_subwindows.tcl`.

Grep for others.

## Traps

- The class binding alone does not fix the popup: the filter runs first, forwards to the
  engine and does not break. Without the refusal one key press would pop the box AND flip
  the mode.
- Rows GH1 and GH2 scan `install_default_binds` for the literal `bind WaveViewer <seq>`
  text, and GH3 needs `-label {X} -accelerator Y` on one source line. The quiz suite's
  proofs quote existing `bind WaveViewer` lines verbatim: do not reformat those.
- `tests/headless/test_wave_sigbrowser_keys.tcl` matches the exact text of the filter's
  present forward expression (row BK01) and evaluates it (BK02). Keep that line or move
  those rows in the same change, and take the suite's baseline first: one of its rows
  was red in the private tree before any of this.
- `install_default_binds` runs once per session; a suite that opened a viewer before
  your binding existed in that process will not see it.
- `m` and `d` are forwarded with read-only lifted, so a refusal for them has to happen in
  Tcl before the forward.
- `test_wave_markers` has the most rows on these keys, is in no list, and times out
  (issue 1488). It is not the fence for this item.
- If you file an issue: this clone's pointer reads 1727 and that number is free; 1728 is
  taken in `~/private/xschem-private` and its pointer reads 1729. A second number tonight
  takes the two checks again; it is not the pointer plus one.

## Out of scope

The Signal Browser's own keys; any change to what a key does over a graph embedded in a
schematic; the Ctrl-Shift-4 binding on the design window.

## Done means

Rows 1 to 9 green on the arm each belongs to, each new row shown red on the unchanged
product (or, for the dangerous siblings, through the decision), the family table true
after the change as measured, and the texts above saying what the code does.
