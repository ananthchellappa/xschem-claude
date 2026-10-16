# 1662 — Waveform Viewer right-click menus posted nothing in multi mode: both menu gates refused every one-trace strip

**STAMP:** `v1 claim=fixed tree=9beec4c4 stamped=2026-10-16 fix=taken open=0`

Reported by the user, 2026-10-16: *"I have lost the right-click (context menus) menus I used to
get with right-click - to do things like split strip, etc. What happened?"*

## What the user saw

Right-click on a trace, on a legend name or on empty plot space did nothing, in every strip of
every subwindow. The user works in **multi** plot mode (their action log `/tmp/Xschem.log.8`
shows multi mode and several `new_subwin` calls).

## Cause

The menu wiring was fine. Reproduced on `:99` with real `<ButtonPress-3>` / `<ButtonRelease-3>`
events and the real `tk_popup` against a real tb_bandgap run: bindtags
`{.x1.drw WaveViewer Frame .x1 all}`, `<ButtonRelease-3>` = `wviewer::btn3_filter`, no grab.
What refused were the two gates:

- `wviewer::trace_menu_pick` returned "no menu" when `wviewer::node_count` of the strip was
  below 2, so that the menu never offered a "Move to Separate Strip" that
  `wviewer::move_trace_to_new_strip` would refuse.
- `wviewer::strip_menu_pick` had the same rung, mirroring `wviewer::split_strip`.

So a strip holding one trace had no menu anywhere: body, empty space or legend. On the legend
it was worse: `btn3_filter` swallowed the press (`legend_slot_at`) and the release gate then
refused, so the click did nothing at all. "Delete Trace" (`625391ad3`) was unreachable on a
one-trace strip, where deleting the only trace makes sense.

| state | traces per strip | result at `9beec4c4` |
|---|---|---|
| single mode | `5` | trace menu and strip menu both post |
| multi mode | `1 1 1 1 1` | nothing posts, anywhere |
| two subwindows | `1 1 1 1 1 \| 5` | nothing in subwindow 1; both in subwindow 2's 5-trace strip |

## Introducing commit

The gates are old (viewer plan items 7 and 8). What exposed them is `7cdb6d709`
*"fix(ase): '~' and the run-end auto-plot follow the viewer's plot mode (R-OUT14)"*. Before
it, `ase::ui::auto_plot` always rebuilt one strip holding every ticked signal, so a `~` strip
always had two or more traces and both menus posted. After it, multi mode gives one strip per
signal. The subwindow commits only multiply the one-trace strips. This is from reading that
diff, not a bisect build.

The suites missed it because `test_wave_trace_menu` and `test_wave_split_strip` drive 3-trace
strips and spy on `tk_popup`, and both PINNED the refusal as correct (TG7, SG7).

## Fix

- Both gates lose the trace-count refusal. `strip_menu_pick` keeps "at least one drawn trace"
  (an empty strip still posts nothing).
- The entries that need two traces are greyed out (`-state disabled`) instead:
  "Move to Separate Strip" in `wviewer::trace_menu_build`, "Split Strip" in
  `wviewer::strip_menu_build` (whose header now says `1 trace`). "Delete Trace" stays live.
- The commands keep their own refusals, so a hand-typed call is still refused.

## Fences

- `test_wave_subwindows` **SWK17** (display): real RMB on every strip of a multi-mode,
  one-trace-per-strip layout, in two subwindows and then one, with the real `tk_popup`:
  the menu is mapped and its entries and states are asserted; a two-trace control strip
  offers both entries live.
- `test_wave_trace_menu` TG7 and `test_wave_split_strip` SG7/SG9b restated: a one-trace strip
  resolves at the gate and its entry is greyed.
- Red at `9beec4c4`, measured: SWK17 (x2), TG7 (x2), SG7, SG9b.

Other right-click surfaces checked and unaffected: the Signal Browser tree and search menus
(`test_wave_sigbrowser`), ASE-L panes, the Calculator stack, the xschem tab menu.

`test_wave_split_strip` is registered in no T1 list; its changed rows run by hand and in
`full_audit.sh` only.
